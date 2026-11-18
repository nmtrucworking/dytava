import '../infrastructure/mobile_input_port.dart';
import '../infrastructure/mobile_export_port.dart';
import '../infrastructure/mobile_comparison_port.dart';
import '../application/workflow_controller.dart';
import '../infrastructure/demo/demo_workflow_ports.dart';

/// Explicit, fixture-only composition until platform adapters are admitted.
WorkflowController createDemoWorkflow() => WorkflowController(
  input: DemoInputPort(),
  comparator: DemoComparisonPort(),
  exporter: DemoExportPort(),
);

/// Native web-parity comparison with background computation.
WorkflowController createMobileWorkflow() => WorkflowController(
  input: MobileInputPort(),
  comparator: MobileComparisonPort(),
  exporter: MobileExportPort(),
);
