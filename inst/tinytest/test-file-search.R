library(Rbebelm)

tmp <- tempfile("rbebelm-fff-")
dir.create(tmp)
dir.create(file.path(tmp, "src"))
writeLines("alpha", file.path(tmp, "src", "apple_banana.R"))
writeLines("beta", file.path(tmp, "src", "mango.txt"))
writeLines("gamma", file.path(tmp, "README-agent.md"))

finder <- bebel_file_finder(tmp, watch = FALSE, wait_timeout_ms = 10000)
expect_true(inherits(finder, "BebelFileFinder"))
info <- finder$info()
expect_equal(info$engine, "fff-search/fff-c")
expect_true(info$native)

res <- bebel_file_search(finder, query = "apple", limit = 10)
expect_true(inherits(res, "bebelFileSearchResult"))
expect_true(nrow(res) >= 1L)
expect_true(any(grepl("apple_banana[.]R$", res$path)))
expect_true(!is.null(attr(res, "total_files")))

one_shot <- bebel_file_search(tmp, query = "readme", limit = 5)
expect_true(any(grepl("README-agent[.]md$", one_shot$path)))

tools <- bebel_default_r_tools(cwd = tmp)
out <- tools$list_files$tool$fun(list(query = "mango", limit = 5L), new.env(parent = emptyenv()), list(name = "list_files"))
expect_true(grepl("mango[.]txt", out))
