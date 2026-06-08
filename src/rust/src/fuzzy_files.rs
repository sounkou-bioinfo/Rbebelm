use crate::util::{checked_usize, err};

fn timeout_ms_to_duration(timeout_ms: Option<f64>, default_ms: u64, name: &str) -> savvy::Result<std::time::Duration> {
    let ms = match timeout_ms {
        None => default_ms,
        Some(v) if v.is_finite() && v >= 0.0 && v.fract() == 0.0 && v <= u64::MAX as f64 => v as u64,
        Some(_) => return Err(err(format!("{name} must be a non-negative whole number of milliseconds"))),
    };
    Ok(std::time::Duration::from_millis(ms))
}

fn option_i32(value: Option<f64>, default: i32, name: &str) -> savvy::Result<i32> {
    match value {
        None => Ok(default),
        Some(v) if v.is_finite() && v.fract() == 0.0 && v >= i32::MIN as f64 && v <= i32::MAX as f64 => Ok(v as i32),
        Some(_) => Err(err(format!("{name} must be a whole number"))),
    }
}

fn usize_or_default(value: Option<f64>, default: usize, name: &str) -> savvy::Result<usize> {
    Ok(checked_usize(value, name)?.unwrap_or(default))
}

#[cfg(not(target_os = "emscripten"))]
mod native {
    use std::path::{Path, PathBuf};

    use fff_search::git::format_git_status;
    use fff_search::{
        FFFMode, FilePicker, FilePickerOptions, FrecencyTracker, FuzzySearchOptions,
        PaginationArgs, QueryParser, QueryTracker, SharedFilePicker, SharedFrecency,
        SharedQueryTracker,
    };
    use savvy::{savvy, OwnedIntegerSexp, OwnedListSexp, OwnedLogicalSexp, OwnedRealSexp, OwnedStringSexp};

    use crate::fuzzy_files::{option_i32, timeout_ms_to_duration, usize_or_default};
    use crate::util::{bool_scalar, checked_usize, err, int_scalar, str_scalar};

    /// Persistent native FFF fuzzy file finder.
    /// @export
    #[savvy]
    pub struct BebelFileFinder {
        picker: SharedFilePicker,
        _frecency: SharedFrecency,
        query_tracker: SharedQueryTracker,
        base_path: String,
        watch: bool,
        enable_mmap_cache: bool,
        enable_content_indexing: bool,
        ai_mode: bool,
    }

    fn optional_path(path: &str) -> Option<PathBuf> {
        let trimmed = path.trim();
        if trimmed.is_empty() {
            None
        } else {
            Some(PathBuf::from(trimmed))
        }
    }

    fn init_frecency(shared: &SharedFrecency, db_path: &str) -> savvy::Result<()> {
        let Some(path) = optional_path(db_path) else {
            return Ok(());
        };
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent).map_err(|e| err(format!("cannot create frecency db directory: {e}")))?;
        }
        let tracker = FrecencyTracker::open(&path).map_err(|e| err(format!("cannot open FFF frecency db: {e}")))?;
        shared.init(tracker).map_err(|e| err(format!("cannot initialize FFF frecency db: {e}")))
    }

    fn init_query_tracker(shared: &SharedQueryTracker, db_path: &str) -> savvy::Result<()> {
        let Some(path) = optional_path(db_path) else {
            return Ok(());
        };
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent).map_err(|e| err(format!("cannot create query-history db directory: {e}")))?;
        }
        let tracker = QueryTracker::open(&path).map_err(|e| err(format!("cannot open FFF query-history db: {e}")))?;
        shared.init(tracker).map_err(|e| err(format!("cannot initialize FFF query-history db: {e}")))
    }

    fn make_string_vec(values: &[String]) -> savvy::Result<OwnedStringSexp> {
        let mut out = OwnedStringSexp::new(values.len())?;
        for (i, value) in values.iter().enumerate() {
            out.set_elt(i, value)?;
        }
        Ok(out)
    }

    fn make_i32_vec(values: &[i32]) -> savvy::Result<OwnedIntegerSexp> {
        let mut out = OwnedIntegerSexp::new(values.len())?;
        for (i, value) in values.iter().enumerate() {
            out.set_elt(i, *value)?;
        }
        Ok(out)
    }

    fn make_f64_vec(values: &[f64]) -> savvy::Result<OwnedRealSexp> {
        let mut out = OwnedRealSexp::new(values.len())?;
        for (i, value) in values.iter().enumerate() {
            out.set_elt(i, *value)?;
        }
        Ok(out)
    }

    fn make_bool_vec(values: &[bool]) -> savvy::Result<OwnedLogicalSexp> {
        let mut out = OwnedLogicalSexp::new(values.len())?;
        for (i, value) in values.iter().enumerate() {
            out.set_elt(i, *value)?;
        }
        Ok(out)
    }

    #[savvy]
    impl BebelFileFinder {
        /// Create a native FFF fuzzy file finder.
        /// @export
        fn new(
            base_path: &str,
            frecency_db_path: &str,
            history_db_path: &str,
            enable_mmap_cache: bool,
            enable_content_indexing: bool,
            watch: bool,
            ai_mode: bool,
            wait_timeout_ms: Option<f64>,
        ) -> savvy::Result<Self> {
            let base = Path::new(base_path);
            let base_path = base
                .canonicalize()
                .unwrap_or_else(|_| base.to_path_buf())
                .to_string_lossy()
                .into_owned();

            let picker = SharedFilePicker::default();
            let frecency = SharedFrecency::default();
            let query_tracker = SharedQueryTracker::default();

            init_frecency(&frecency, frecency_db_path)?;
            init_query_tracker(&query_tracker, history_db_path)?;

            FilePicker::new_with_shared_state(
                picker.clone(),
                frecency.clone(),
                FilePickerOptions {
                    base_path: base_path.clone(),
                    enable_mmap_cache,
                    enable_content_indexing,
                    watch,
                    mode: if ai_mode { FFFMode::Ai } else { FFFMode::Neovim },
                    cache_budget: None,
                    follow_symlinks: false,
                    enable_fs_root_scanning: false,
                    enable_home_dir_scanning: false,
                },
            )
            .map_err(|e| err(format!("cannot initialize FFF file finder: {e}")))?;

            let timeout = timeout_ms_to_duration(wait_timeout_ms, 10_000, "wait_timeout_ms")?;
            if !picker.wait_for_indexing_complete(timeout) {
                return Err(err("timed out waiting for FFF initial scan"));
            }

            Ok(Self {
                picker,
                _frecency: frecency,
                query_tracker,
                base_path,
                watch,
                enable_mmap_cache,
                enable_content_indexing,
                ai_mode,
            })
        }

        /// Return file-finder metadata.
        /// @export
        fn info(&self) -> savvy::Result<savvy::Sexp> {
            let mut out = OwnedListSexp::new(7, true)?;
            out.set_name_and_value(0, "base_path", str_scalar(&self.base_path)?)?;
            out.set_name_and_value(1, "engine", str_scalar("fff-search/fff-c")?)?;
            out.set_name_and_value(2, "native", bool_scalar(true)?)?;
            out.set_name_and_value(3, "watch", bool_scalar(self.watch)?)?;
            out.set_name_and_value(4, "enable_mmap_cache", bool_scalar(self.enable_mmap_cache)?)?;
            out.set_name_and_value(5, "enable_content_indexing", bool_scalar(self.enable_content_indexing)?)?;
            out.set_name_and_value(6, "ai_mode", bool_scalar(self.ai_mode)?)?;
            out.into()
        }

        /// Wait for the current FFF scan/indexing job to finish.
        /// @export
        fn wait(&self, timeout_ms: Option<f64>) -> savvy::Result<savvy::Sexp> {
            let timeout = timeout_ms_to_duration(timeout_ms, 10_000, "timeout_ms")?;
            bool_scalar(self.picker.wait_for_indexing_complete(timeout))?.into()
        }

        /// Search indexed files with FFF fuzzy matching.
        /// @export
        fn search(
            &self,
            query: &str,
            current_file: &str,
            max_threads: Option<f64>,
            offset: Option<f64>,
            limit: Option<f64>,
            combo_boost_score_multiplier: Option<f64>,
            min_combo_count: Option<f64>,
            wait_timeout_ms: Option<f64>,
        ) -> savvy::Result<savvy::Sexp> {
            let timeout = timeout_ms_to_duration(wait_timeout_ms, 10_000, "wait_timeout_ms")?;
            if !self.picker.wait_for_indexing_complete(timeout) {
                return Err(err("timed out waiting for FFF index"));
            }

            let max_threads = usize_or_default(max_threads, 0, "max_threads")?;
            let offset = usize_or_default(offset, 0, "offset")?;
            let limit = usize_or_default(limit, 100, "limit")?;
            let combo_boost_score_multiplier = option_i32(combo_boost_score_multiplier, 100, "combo_boost_score_multiplier")?;
            let min_combo_count = checked_usize(min_combo_count, "min_combo_count")?.unwrap_or(3) as u32;
            let current_file = if current_file.trim().is_empty() { None } else { Some(current_file) };

            let picker_guard = self
                .picker
                .read()
                .map_err(|e| err(format!("cannot read FFF file finder: {e}")))?;
            let picker = picker_guard
                .as_ref()
                .ok_or_else(|| err("FFF file finder is not initialized"))?;

            let query_tracker_guard = self
                .query_tracker
                .read()
                .map_err(|e| err(format!("cannot read FFF query tracker: {e}")))?;
            let query_tracker = query_tracker_guard.as_ref();
            let parser = QueryParser::default();
            let parsed = parser.parse(query);
            let results = picker.fuzzy_search(
                &parsed,
                query_tracker,
                FuzzySearchOptions {
                    max_threads,
                    current_file,
                    project_path: Some(picker.base_path()),
                    combo_boost_score_multiplier,
                    min_combo_count,
                    pagination: PaginationArgs { offset, limit },
                },
            );

            let n = results.items.len();
            let mut path = Vec::with_capacity(n);
            let mut absolute_path = Vec::with_capacity(n);
            let mut file_name = Vec::with_capacity(n);
            let mut git_status = Vec::with_capacity(n);
            let mut size = Vec::with_capacity(n);
            let mut modified = Vec::with_capacity(n);
            let mut score_total = Vec::with_capacity(n);
            let mut score_base = Vec::with_capacity(n);
            let mut match_type = Vec::with_capacity(n);
            let mut exact_match = Vec::with_capacity(n);
            let mut is_binary = Vec::with_capacity(n);

            for (item, score) in results.items.iter().zip(results.scores.iter()) {
                let relative = item.relative_path(picker);
                let absolute = picker.base_path().join(&relative).to_string_lossy().into_owned();
                path.push(relative);
                absolute_path.push(absolute);
                file_name.push(item.file_name(picker));
                git_status.push(format_git_status(item.git_status).to_string());
                size.push(item.size as f64);
                modified.push(item.modified as f64);
                score_total.push(score.total);
                score_base.push(score.base_score);
                match_type.push(score.match_type.to_string());
                exact_match.push(score.exact_match);
                is_binary.push(item.is_binary());
            }

            let mut out = OwnedListSexp::new(14, true)?;
            out.set_name_and_value(0, "path", make_string_vec(&path)?)?;
            out.set_name_and_value(1, "absolute_path", make_string_vec(&absolute_path)?)?;
            out.set_name_and_value(2, "file_name", make_string_vec(&file_name)?)?;
            out.set_name_and_value(3, "git_status", make_string_vec(&git_status)?)?;
            out.set_name_and_value(4, "size", make_f64_vec(&size)?)?;
            out.set_name_and_value(5, "modified", make_f64_vec(&modified)?)?;
            out.set_name_and_value(6, "score", make_i32_vec(&score_total)?)?;
            out.set_name_and_value(7, "base_score", make_i32_vec(&score_base)?)?;
            out.set_name_and_value(8, "match_type", make_string_vec(&match_type)?)?;
            out.set_name_and_value(9, "exact_match", make_bool_vec(&exact_match)?)?;
            out.set_name_and_value(10, "is_binary", make_bool_vec(&is_binary)?)?;
            out.set_name_and_value(11, "total_matched", int_scalar(results.total_matched.min(i32::MAX as usize) as i32)?)?;
            out.set_name_and_value(12, "total_files", int_scalar(results.total_files.min(i32::MAX as usize) as i32)?)?;
            out.set_name_and_value(13, "query", str_scalar(query)?)?;
            out.into()
        }
    }
}

#[cfg(target_os = "emscripten")]
mod wasm_stub {
    use savvy::{savvy, OwnedListSexp};

    use crate::fuzzy_files::timeout_ms_to_duration;
    use crate::util::{bool_scalar, err, str_scalar};

    /// Persistent native FFF fuzzy file finder.
    /// @export
    #[savvy]
    pub struct BebelFileFinder {}

    #[savvy]
    impl BebelFileFinder {
        /// Create a native FFF fuzzy file finder.
        /// @export
        fn new(
            base_path: &str,
            frecency_db_path: &str,
            history_db_path: &str,
            enable_mmap_cache: bool,
            enable_content_indexing: bool,
            watch: bool,
            ai_mode: bool,
            wait_timeout_ms: Option<f64>,
        ) -> savvy::Result<Self> {
            let _ = (base_path, frecency_db_path, history_db_path, enable_mmap_cache, enable_content_indexing, watch, ai_mode, wait_timeout_ms);
            Err(err("FFF fuzzy file search is native-only and is not available in webR/wasm"))
        }

        /// Return file-finder metadata.
        /// @export
        fn info(&self) -> savvy::Result<savvy::Sexp> {
            let mut out = OwnedListSexp::new(3, true)?;
            out.set_name_and_value(0, "engine", str_scalar("fff-search/fff-c")?)?;
            out.set_name_and_value(1, "native", bool_scalar(false)?)?;
            out.set_name_and_value(2, "available", bool_scalar(false)?)?;
            out.into()
        }

        /// Wait for the current FFF scan/indexing job to finish.
        /// @export
        fn wait(&self, timeout_ms: Option<f64>) -> savvy::Result<savvy::Sexp> {
            let _ = timeout_ms_to_duration(timeout_ms, 10_000, "timeout_ms")?;
            bool_scalar(false)?.into()
        }

        /// Search indexed files with FFF fuzzy matching.
        /// @export
        fn search(
            &self,
            query: &str,
            current_file: &str,
            max_threads: Option<f64>,
            offset: Option<f64>,
            limit: Option<f64>,
            combo_boost_score_multiplier: Option<f64>,
            min_combo_count: Option<f64>,
            wait_timeout_ms: Option<f64>,
        ) -> savvy::Result<savvy::Sexp> {
            let _ = (query, current_file, max_threads, offset, limit, combo_boost_score_multiplier, min_combo_count, wait_timeout_ms);
            Err(err("FFF fuzzy file search is native-only and is not available in webR/wasm"))
        }
    }
}

#[cfg(not(target_os = "emscripten"))]
#[allow(unused_imports)]
pub use native::BebelFileFinder;
#[cfg(target_os = "emscripten")]
pub use wasm_stub::BebelFileFinder;
