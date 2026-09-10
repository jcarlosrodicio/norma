# Stub stack adapter: the gate's own logic is what is under test, not a toolchain.
HARNESS_CODE_PATHS="src spec"
harness_gates() { echo "STUB gates"; }
harness_test_selected() { echo "STUB selected: $*"; }
harness_test_all() { echo "STUB all"; }
