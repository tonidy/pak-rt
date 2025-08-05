# Project Structure

## Current Organization
```
pak-rt/
├── .kiro/
│   └── steering/
│       ├── product.md
│       ├── tech.md
│       └── structure.md
```

## Recommended Structure Patterns
When developing this project, consider these common organizational patterns:

### Web Application Structure
```
src/
├── components/     # Reusable UI components
├── pages/         # Page-level components
├── utils/         # Helper functions
├── styles/        # CSS/styling files
├── assets/        # Images, fonts, etc.
└── config/        # Configuration files

tests/             # Test files
docs/              # Documentation
public/            # Static assets
```

### Backend API Structure
```
src/
├── controllers/   # Request handlers
├── models/        # Data models
├── services/      # Business logic
├── middleware/    # Custom middleware
├── routes/        # API routes
└── utils/         # Helper functions

tests/             # Test files
config/            # Configuration
migrations/        # Database migrations (if applicable)
```

## Naming Conventions
- Use kebab-case for file and folder names
- Use camelCase for JavaScript variables and functions
- Use PascalCase for components and classes
- Keep names descriptive and concise

## File Organization Principles
- Group related functionality together
- Separate concerns (UI, logic, data)
- Keep configuration files at appropriate levels
- Maintain clear separation between source and build artifacts