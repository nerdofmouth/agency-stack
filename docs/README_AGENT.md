# AgencyStack Documentation - AI Agent Guidelines

## Directory Purpose

This directory contains all documentation for the AgencyStack platform, including the Charter, component documentation, and operational guides. Following the AgencyStack Charter v1.0.3 principles, documentation must be maintained alongside code changes to ensure consistency and auditability.

## AI Agent Interaction Guidelines

### 🚫 Critical Restrictions

- **NEVER modify documentation without corresponding code changes**
- **NEVER document practices that violate the Charter principles**
- **NEVER encourage host-level installation or direct VM modifications**

### ✅ Required Practices

1. **Charter Alignment:** All documentation must align with the AgencyStack Charter v1.0.3.
2. **Component Documentation:** Every component must have corresponding documentation in `/docs/pages/components/`.
3. **Update Documentation:** When modifying code behavior, always update the relevant docs.
4. **Testing Documentation:** Include testing instructions and expected outcomes for each component.
5. **Human-Readable Format:** Use clear, concise markdown with appropriate headers, lists, and code examples.

### 📁 Directory Structure

```
/docs/
├── charter/         # Charter definitions and principles
│   ├── v1.0.3.md    # Current Charter version
│   └── tdd_protocol.md  # Test-Driven Development Protocol
├── pages/           # Component and feature documentation
│   └── components/  # Individual component documentation
└── tutorials/       # Step-by-step guides for operators
```

## Documentation Development Workflow

1. Use existing documentation as templates for consistency
2. Follow the documentation structure defined in the Charter
3. Include sections for: Purpose, Installation, Configuration, Testing, and Troubleshooting
4. Document both expected behavior and edge cases
5. Include clear examples and command references
6. Link to related components and dependencies

## Key References

- [AgencyStack Charter v1.0.3](/docs/charter/v1.0.3.md)
- [Test-Driven Development Protocol](/docs/charter/tdd_protocol.md)
- [Component Documentation Template](/docs/pages/templates/component_template.md)

All documentation should emphasize the strict containerization principles of AgencyStack and clarify that no component should ever be installed directly on a host system.
