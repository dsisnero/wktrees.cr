# PR Workflow

1. Create a feature branch.
2. Implement changes following the porting workflow.
3. Ensure all quality gates pass:
   ```bash
   make format
   make lint
   make test
   ```
4. Update `plans/inventory/rust_port_inventory.tsv` if applicable.
5. Submit a pull request with a description referencing the upstream commit
   used for translation.
