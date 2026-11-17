import '../application/workflow_controller.dart';
import '../infrastructure/demo/demo_workflow_ports.dart';

/// Explicit, fixture-only composition until platform adapters are admitted.
WorkflowController createDemoWorkflow() => WorkflowController(
  input: DemoInputPort(),
  comparator: DemoComparisonPort(),
  exporter: DemoExportPort(),
);
