workflow "Test" {
  on = "push"
  resolves = ["test"]
}

action "test" {
  uses = "ilyapuchka/SwiftGitHubAction@swift5"
  args = "test"
}
