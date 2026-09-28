"""Named fakes for accounts' external I/O (AGENTS.md: named fakes, not inline stubs)."""

from dataclasses import dataclass, field


@dataclass
class FakeGoogleVerifier:
    """Stands in for google.oauth2.id_token.verify_oauth2_token.

    Returns ``idinfo`` for any token and records the audience it was asked
    to check, so a test can assert which clients the view accepts.
    """

    idinfo: dict[str, object]
    audiences_seen: list[object] = field(default_factory=list)

    def __call__(self, token: str, request: object, audience: object = None) -> dict[str, object]:
        self.audiences_seen.append(audience)
        return self.idinfo
