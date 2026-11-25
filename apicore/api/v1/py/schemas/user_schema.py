"""User input schema: field rules of the `users` entity.

Layer: schemas (cross-cutting). Validation only: no HTTP, no SQL. Business rules
(duplicated username/email, password hashing, role permissions) live in the controller.
"""
import re

from schemas.base_schema import validate_date, validate_enum, validate_string

REQUIRED = {'Username': 16, 'Name': 45, 'PaternalSurname': 25}
OPTIONAL = {'MaternalSurname': 25, 'Email': 100, 'Phone': 15, 'EmergencyPhone': 15}
STATUSES = ('Active', 'Inactive')
ROLES = ('God', 'Admin', 'User', 'Other')

EMAIL_PATTERN = re.compile(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
PHONE_PATTERN = re.compile(r'^\+?[0-9 ()-]{7,15}$')


def validate(data, partial=False):
    """Validate a user payload. partial=True (PATCH) checks only the fields sent."""
    for field, max_length in {**REQUIRED, **OPTIONAL}.items():
        validate_string(data, field, max_length=max_length,
                        required=field in REQUIRED, partial=partial)
    if data.get('Email') and not EMAIL_PATTERN.match(data['Email']):
        raise ValueError('Email is not a valid email address')
    for field in ('Phone', 'EmergencyPhone'):
        if data.get(field) and not PHONE_PATTERN.match(data[field]):
            raise ValueError(f'{field} must contain only digits, spaces, +, - or ()')
    validate_date(data, 'BirthDate', partial=partial)
    validate_enum(data, 'UserStatus', STATUSES, partial)
    if 'UserRole' in data:
        validate_enum(data, 'UserRole', ROLES)
