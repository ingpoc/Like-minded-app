# Project Context

Local CLI for a project-specific context graph.

Use the repo wrapper instead of invoking this package directly:

```bash
./script/project_context.sh doctor
./script/project_context.sh session-start
./script/project_context.sh query --task "current task"
```

Fresh clone (graph.db is gitignored):

```bash
./script/bootstrap_context_graph_decisions.sh
```
