agent_front_matter <- function(text) {
  lines <- strsplit(text, "\n", fixed = TRUE)[[1L]]
  if (length(lines) < 3L || !identical(trimws(lines[[1L]]), "---")) return(list(fields = list(), body = text))
  end <- which(trimws(lines[-1L]) == "---")
  if (!length(end)) return(list(fields = list(), body = text))
  end <- end[[1L]] + 1L
  yaml_lines <- lines[seq.int(2L, end - 1L)]
  fields <- list()
  for (line in yaml_lines) {
    if (!grepl(":", line, fixed = TRUE)) next
    key <- trimws(sub(":.*$", "", line))
    value <- trimws(sub("^[^:]*:", "", line))
    value <- sub('^(["\\\'])(.*)\\1$', "\\2", value, perl = TRUE)
    if (nzchar(key)) fields[[key]] <- value
  }
  body <- paste(lines[-seq_len(end)], collapse = "\n")
  list(fields = fields, body = body)
}

#' Define a framework skill
#'
#' A skill is reusable instruction/context text plus metadata. Skill providers
#' list and load skills; the loop or prompt-composition layer decides when to
#' include them.
#'
#' @param name Skill name.
#' @param content Skill content.
#' @param description Optional description.
#' @param metadata Optional metadata list.
#' @param path Optional source path.
#' @return An `agentSkill` object.
#' @export
agent_skill <- function(name, content, description = NULL, metadata = list(), path = NULL) {
  if (!is.character(name) || length(name) != 1L || !nzchar(name)) stop("skill name must be a non-empty string", call. = FALSE)
  structure(
    list(name = name, description = description %||% name, content = as.character(content)[[1L]], metadata = metadata, path = path),
    class = "agentSkill"
  )
}

agent_skill_from_file <- function(path) {
  text <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  parsed <- agent_front_matter(text)
  name <- parsed$fields$name %||% tools::file_path_sans_ext(basename(path))
  if (identical(basename(path), "SKILL.md")) name <- basename(dirname(path))
  agent_skill(
    name = name,
    content = parsed$body,
    description = parsed$fields$description %||% name,
    metadata = parsed$fields,
    path = normalizePath(path, winslash = "/", mustWork = FALSE)
  )
}

agent_normalize_skills <- function(skills = list(), paths = character()) {
  if (is.null(skills)) skills <- list()
  if (inherits(skills, "agentSkill") || is.character(skills)) skills <- list(skills)
  out <- list()
  for (i in seq_along(skills)) {
    skill <- skills[[i]]
    if (inherits(skill, "agentSkill")) {
      out[[skill$name]] <- skill
    } else if (is.character(skill) && length(skill) == 1L) {
      nm <- names(skills)[i]
      if (is.null(nm) || !nzchar(nm)) stop("character skills must be named", call. = FALSE)
      out[[nm]] <- agent_skill(nm, skill)
    } else {
      stop("skills must contain agentSkill objects or named character content", call. = FALSE)
    }
  }
  for (path in paths %||% character()) {
    candidates <- if (dir.exists(path)) list.files(path, pattern = "(^SKILL[.]md$|[.]md$)", recursive = TRUE, full.names = TRUE) else path
    for (candidate in candidates[file.exists(candidates)]) {
      skill <- agent_skill_from_file(candidate)
      out[[skill$name]] <- skill
    }
  }
  out
}

#' Create a skill provider
#'
#' @param skills `agentSkill` objects or named character skill bodies.
#' @param paths Skill markdown files or directories to scan. `SKILL.md` files use
#'   their parent directory name as the skill name.
#' @param name Provider name.
#' @return An `agentSkillProvider` implementing [SkillProvider].
#' @export
agent_skill_provider <- function(skills = list(), paths = character(), name = "default") {
  structure(list(name = name, skills = agent_normalize_skills(skills, paths)), class = "agentSkillProvider")
}

AgentSkillProviderS3 <- S7::new_S3_class("agentSkillProvider")

S7::method(skill_list, AgentSkillProviderS3) <- function(provider) {
  data.frame(
    name = names(provider$skills),
    description = vapply(provider$skills, function(x) x$description %||% "", character(1)),
    path = vapply(provider$skills, function(x) x$path %||% NA_character_, character(1)),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

S7::method(skill_load, AgentSkillProviderS3) <- function(provider, name) {
  skill <- provider$skills[[as.character(name)[[1L]]]]
  if (is.null(skill)) stop("unknown skill: ", name, call. = FALSE)
  skill
}

#' Define a prompt template
#'
#' Prompt templates are backend-agnostic named text templates. Rendering is kept
#' deliberately small and portable: `{{name}}` placeholders are replaced by
#' values in `data`.
#'
#' @param name Template name.
#' @param template Template text.
#' @param description Optional description.
#' @param metadata Optional metadata list.
#' @param path Optional source path.
#' @return An `agentPromptTemplate` object.
#' @export
agent_prompt_template <- function(name, template, description = NULL, metadata = list(), path = NULL) {
  if (!is.character(name) || length(name) != 1L || !nzchar(name)) stop("template name must be a non-empty string", call. = FALSE)
  structure(
    list(name = name, description = description %||% name, template = as.character(template)[[1L]], metadata = metadata, path = path),
    class = "agentPromptTemplate"
  )
}

agent_prompt_template_from_file <- function(path) {
  text <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  parsed <- agent_front_matter(text)
  agent_prompt_template(
    name = parsed$fields$name %||% tools::file_path_sans_ext(basename(path)),
    template = parsed$body,
    description = parsed$fields$description %||% parsed$fields$name %||% basename(path),
    metadata = parsed$fields,
    path = normalizePath(path, winslash = "/", mustWork = FALSE)
  )
}

agent_normalize_prompt_templates <- function(templates = list(), paths = character()) {
  if (is.null(templates)) templates <- list()
  if (inherits(templates, "agentPromptTemplate") || is.character(templates)) templates <- list(templates)
  out <- list()
  for (i in seq_along(templates)) {
    template <- templates[[i]]
    if (inherits(template, "agentPromptTemplate")) {
      out[[template$name]] <- template
    } else if (is.character(template) && length(template) == 1L) {
      nm <- names(templates)[i]
      if (is.null(nm) || !nzchar(nm)) stop("character templates must be named", call. = FALSE)
      out[[nm]] <- agent_prompt_template(nm, template)
    } else {
      stop("templates must contain agentPromptTemplate objects or named character templates", call. = FALSE)
    }
  }
  for (path in paths %||% character()) {
    candidates <- if (dir.exists(path)) list.files(path, pattern = "[.](md|txt|prompt)$", recursive = TRUE, full.names = TRUE) else path
    for (candidate in candidates[file.exists(candidates)]) {
      template <- agent_prompt_template_from_file(candidate)
      out[[template$name]] <- template
    }
  }
  out
}

#' Create a prompt-template provider
#'
#' @param templates `agentPromptTemplate` objects or named character templates.
#' @param paths Template files or directories to scan.
#' @param name Provider name.
#' @return An `agentPromptTemplateProvider` implementing [PromptTemplateProvider].
#' @export
agent_prompt_template_provider <- function(templates = list(), paths = character(), name = "default") {
  structure(list(name = name, templates = agent_normalize_prompt_templates(templates, paths)), class = "agentPromptTemplateProvider")
}

agent_render_template_text <- function(template, data = list()) {
  out <- template
  for (nm in names(data %||% list())) {
    value <- data[[nm]]
    if (length(value) > 1L) value <- paste(as.character(value), collapse = ", ")
    out <- gsub(paste0("{{\\s*", gsub("([\\W])", "\\\\\\1", nm, perl = TRUE), "\\s*}}"), as.character(value), out, perl = TRUE)
  }
  out
}

AgentPromptTemplateProviderS3 <- S7::new_S3_class("agentPromptTemplateProvider")

S7::method(prompt_template_list, AgentPromptTemplateProviderS3) <- function(provider) {
  data.frame(
    name = names(provider$templates),
    description = vapply(provider$templates, function(x) x$description %||% "", character(1)),
    path = vapply(provider$templates, function(x) x$path %||% NA_character_, character(1)),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

S7::method(prompt_template_render, AgentPromptTemplateProviderS3) <- function(provider, name, data = list()) {
  template <- provider$templates[[as.character(name)[[1L]]]]
  if (is.null(template)) stop("unknown prompt template: ", name, call. = FALSE)
  agent_render_template_text(template$template, data)
}

#' Compose a system prompt from a prompt template and optional skills
#'
#' @param provider Object implementing [PromptTemplateProvider].
#' @param name Prompt template name.
#' @param data Template data.
#' @param skill_provider Optional object implementing [SkillProvider].
#' @param skills Character vector of skill names to append.
#' @return Rendered system prompt text.
#' @export
agent_system_prompt <- function(provider, name = "system", data = list(), skill_provider = NULL, skills = character()) {
  bebel_assert_implements(provider, PromptTemplateProvider, arg = "provider")
  prompt <- prompt_template_render(provider, name, data = data)
  if (!is.null(skill_provider) && length(skills)) {
    bebel_assert_implements(skill_provider, SkillProvider, arg = "skill_provider")
    loaded <- lapply(skills, function(skill_name) skill_load(skill_provider, skill_name))
    skill_text <- vapply(loaded, function(skill) paste0("## Skill: ", skill$name, "\n\n", skill$content), character(1))
    prompt <- paste(c(prompt, "# Loaded skills", skill_text), collapse = "\n\n")
  }
  prompt
}

#' Render and append a system prompt to an agent backend
#'
#' @param agent Object implementing [AgentBackend].
#' @inheritParams agent_system_prompt
#' @param tools Optional backend-native tool declarations.
#' @return `agent`, invisibly.
#' @export
agent_append_system_prompt <- function(agent, provider, name = "system", data = list(), skill_provider = NULL, skills = character(), tools = NULL) {
  bebel_assert_implements(agent, AgentBackend, arg = "agent")
  prompt <- agent_system_prompt(provider, name = name, data = data, skill_provider = skill_provider, skills = skills)
  agent_append_system(agent, prompt, tools = tools)
  invisible(agent)
}
