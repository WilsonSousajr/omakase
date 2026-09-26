import pytest
from rest_framework import status

URL = "/api/v1/stats/reviews/"


@pytest.mark.django_db
class TestReviewEnergy:
    def test_energy_is_stored_and_returned(self, authenticated_client):
        resp = authenticated_client.post(URL, {"date": "2026-03-07", "energy": 2}, format="json")
        assert resp.status_code == status.HTTP_201_CREATED, resp.data
        assert resp.data["energy"] == 2

    def test_energy_is_optional(self, authenticated_client):
        resp = authenticated_client.post(URL, {"date": "2026-03-07"}, format="json")
        assert resp.status_code == status.HTTP_201_CREATED
        assert resp.data["energy"] is None

    @pytest.mark.parametrize("energy", [0, 4])
    def test_energy_outside_one_to_three_is_a_400_naming_it(self, authenticated_client, energy):
        resp = authenticated_client.post(URL, {"date": "2026-03-07", "energy": energy}, format="json")
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert f"energy {energy}" in str(resp.data["energy"])
