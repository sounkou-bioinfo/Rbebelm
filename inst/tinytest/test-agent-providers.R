library(Rbebelm)

skills <- bebel_skill_provider(list(cran = "Follow CRAN-safe side-effect rules."), name = "skills")
expect_equal(bebel_skill_list(skills)$name, "cran")
expect_equal(bebel_skill_load(skills, "cran")$content, "Follow CRAN-safe side-effect rules.")

templates <- bebel_prompt_template_provider(list(system = "You are {{role}} working in {{place}}."), name = "prompts")
expect_equal(bebel_prompt_template_render(templates, "system", list(role = "an agent", place = "Bamako")), "You are an agent working in Bamako.")

system <- bebel_system_prompt(templates, data = list(role = "an agent", place = "Bamako"), skill_provider = skills, skills = "cran")
expect_true(grepl("Bamako", system))
expect_true(grepl("Skill: cran", system))

ext <- bebel_extension(
  "provider-demo",
  skill_providers = list(skills = skills),
  prompt_template_providers = list(prompts = templates)
)
manifest <- bebel_extension_manifest(ext)
expect_equal(manifest$skill_providers, "skills")
expect_equal(manifest$prompt_template_providers, "prompts")

tmp <- tempfile("providers-")
dir.create(tmp)
skill_dir <- file.path(tmp, "demo-skill")
dir.create(skill_dir)
writeLines(c("---", "name: demo", "description: Demo skill", "---", "Use concise answers."), file.path(skill_dir, "SKILL.md"))
file_skills <- bebel_skill_provider(paths = tmp)
expect_equal(bebel_skill_load(file_skills, "demo-skill")$description, "Demo skill")

writeLines(c("---", "name: greet", "description: Greeting", "---", "Hello {{name}}"), file.path(tmp, "greet.md"))
file_templates <- bebel_prompt_template_provider(paths = tmp)
expect_equal(bebel_prompt_template_render(file_templates, "greet", list(name = "Mali")), "Hello Mali")
