# SOUL Implementation Checklist

Progress tracking for SOUL subsystem implementation. Each major component is tracked from design through deployment. For detailed requirements, see `SOUL_LLM_Implementation_Specification_FINAL.md`.

## Core Framework
- [ ] Plugin module structure and initialization
- [ ] Plugin hooks registration (commands, events, web handlers)
- [ ] Configuration loading and live-reload support
- [ ] Localization setup (locale files)
- [ ] Database model foundation

## Character Model
- [ ] Character class integration with Ares core
- [ ] Custom character fields (SOUL data attachment)
- [ ] Character lifecycle hooks (creation, deletion, update)
- [ ] Character validation and constraints

## Aspect System
- [ ] Aspect model and storage
- [ ] Aspect configuration structure
- [ ] Aspect validation and constraints
- [ ] Aspect progression tracking

## Skill System
- [ ] Skill model and storage
- [ ] Skill-Aspect relationship
- [ ] Skill advancement mechanics
- [ ] Skill rating validation and constraints
- [ ] Skill display and formatting

## XP System
- [ ] XP tracking and storage
- [ ] XP earning mechanics
- [ ] XP spending/advancement
- [ ] XP log and history
- [ ] XP permission checks

## Catch-Up XP
- [ ] Catch-up XP calculation logic
- [ ] Catch-up XP earning rate
- [ ] Catch-up XP spending rules
- [ ] Catch-up XP configuration

## Resonance System
- [ ] Resonance model and storage
- [ ] Resonance earning mechanics
- [ ] Resonance spending/usage
- [ ] Resonance lifecycle and potential decay
- [ ] Resonance display and tracking

## Boons & Banes System
- [ ] Boon/Bane definition model
- [ ] Character-instance model for B&Bs
- [ ] B&B lifecycle (active, resolved, history)
- [ ] B&B mechanical effects (modifiers, effects)
- [ ] B&B tags and categorization
- [ ] B&B source tracking
- [ ] Default B&B examples in README

## Rolls System
- [ ] Roll model and storage
- [ ] Basic roll mechanics
- [ ] B&B modifier application
- [ ] Scene-policy support
- [ ] Roll result persistence and history
- [ ] Roll display formatting

## Pending Rolls (GM-Assisted)
- [ ] Pending roll queue model
- [ ] GM workflow (approval, rejection, modification)
- [ ] Asynchronous roll resolution
- [ ] Player notifications
- [ ] Timeout/expiration handling

## GM Workflow
- [ ] GM review interface (MUSH commands)
- [ ] GM review interface (web portal)
- [ ] Approval/rejection actions
- [ ] Roll modification capability
- [ ] Audit trail for GM actions

## Commands
- [ ] Character commands (status, sheet, etc.)
- [ ] Skill commands (set, advance, etc.)
- [ ] XP commands (grant, spend, log, etc.)
- [ ] Resonance commands (spend, status, etc.)
- [ ] Boon/Bane commands (create, edit, resolve, etc.)
- [ ] Roll commands (roll, pending, resolve, etc.)
- [ ] Admin commands (config, reset, etc.)

## Request Handlers (Web API)
- [ ] Character API handlers
- [ ] Skill handlers
- [ ] XP handlers
- [ ] Resonance handlers
- [ ] Boon & Bane handlers
- [ ] Roll handlers
- [ ] Pending roll handlers
- [ ] Admin handlers

## Web Portal Integration
- [ ] Character sheet tab component
- [ ] Skills display and management
- [ ] XP tracking display
- [ ] Resonance display
- [ ] Boon & Bane management interface
- [ ] Roll history display
- [ ] Pending roll queue (player and GM views)
- [ ] Configuration panel (admin)

## Configuration
- [ ] Configuration file structure (`game/config/soul.yml`)
- [ ] Default values and sensible defaults
- [ ] Game-specific customization options
- [ ] Validation of configuration values
- [ ] Live reload support

## Permissions
- [ ] Permission structure definition
- [ ] Default permission mappings
- [ ] Permission checks in commands/handlers
- [ ] Permission configuration support
- [ ] Role-based access control

## Testing
- [ ] Unit tests for core logic
- [ ] Integration tests for workflows
- [ ] Web handler tests
- [ ] Permission tests
- [ ] Configuration tests
- [ ] Test fixtures and factories
- [ ] Test coverage reporting

## Documentation
- [ ] Architecture documentation complete
- [ ] API documentation for plugins
- [ ] Player command help files
- [ ] Admin/wizard command help files
- [ ] README with installation and setup
- [ ] Migration guide from FS3
- [ ] Configuration reference
- [ ] Permissions reference
