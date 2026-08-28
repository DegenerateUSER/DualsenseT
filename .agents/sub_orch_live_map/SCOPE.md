# Scope: Live Map UI Redesign

## Objective
Replace the crude layout in `ControllerVisualizerView.swift` with a premium, realistic, and properly proportioned SwiftUI representation of a PlayStation 5 DualSense controller.

## Requirements
- **High-Fidelity Shapes**: White casing outer shell, black inner trim plate, trapezoidal touchpad, flanking lightbar strips.
- **Button Highlights**: Glow/color shift (e.g. blue/cyan) for D-pad, action buttons, shoulders, triggers, options, create, PS button, touchpad click.
- **Analog Sticks**: Display L3/R3 CGPoint displacements inside circular wells with correct scaling/positioning.
- **Trigger Fill**: Animate L2/R2 physical depth (0.0 to 1.0) on the trigger visuals.
- **Touchpad Markers**: Display touch markers in real-time.
- **LED State**: Adapt to active manager LED color and pulse speed/animation.
- **HUD Glassmorphism**: Fit dark mode / glassmorphism UI theme responsively.

## Milestones
1. Analyze existing view coordinates, layouts, and subcomponents.
2. Refactor shapes and styling to ensure proportions and dimensions are realistic.
3. Wire up interactions and animations.
4. Verify compiling via `./build.sh` and correct runtime visual display.
