import pytest

from app.security import (
    TokenError,
    hash_password,
    issue_token,
    verify_password,
    verify_token,
)


def test_password_hash_is_not_plaintext_and_verifies():
    password = "SyntheticPass-123"
    password_hash = hash_password(password)

    assert password_hash != password
    assert verify_password(password, password_hash)
    assert not verify_password("wrong-password", password_hash)


def test_signed_token_round_trip_and_expiration():
    token = issue_token(42, "s" * 32, ttl_seconds=60, now=1_000)

    assert verify_token(token, "s" * 32, now=1_059) == 42
    with pytest.raises(TokenError):
        verify_token(token, "s" * 32, now=1_060)


def test_modified_token_is_rejected():
    token = issue_token(7, "s" * 32, ttl_seconds=60, now=1_000)
    payload, signature = token.split(".")

    with pytest.raises(TokenError):
        verify_token(f"{payload}.{signature[:-1]}x", "s" * 32, now=1_001)

