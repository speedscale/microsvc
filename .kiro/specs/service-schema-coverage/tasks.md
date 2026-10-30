# Service schema coverage tasks

- [x] Specify accepted-spec coverage separately from the gateway's golden-operation coverage.
- [x] Document the existing native coverage/validate commands and their distinct success semantics.
- [ ] Select and review the service's OpenAPI contract, including response models and known omissions; pin its hash.
- [ ] Verify the selected service runs locally with recorded dependency mocks using its actual runtime.
- [ ] Retain original and observed-replay native coverage JSON against the fixed spec; display operations, statuses, fields and gaps.
- [ ] Prove incomplete-but-valid, schema-violation, empty/unmatched and supplemental-executed-case controls.
- [ ] Apply the agreed acceptance policy in the existing test/pre-commit entry point and verify blocked/passing behavior.

Checked specification tasks do not mark service execution, runtime integration or product rollout complete.
