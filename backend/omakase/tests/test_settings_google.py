from omakase.settings import google_client_ids


def test_reads_every_client_from_the_list():
    assert google_client_ids({"GOOGLE_CLIENT_IDS": "web.apps, mac.apps ,,"}) == ["web.apps", "mac.apps"]


def test_falls_back_to_the_single_variable_for_one_release():
    assert google_client_ids({"GOOGLE_CLIENT_ID": "web.apps"}) == ["web.apps"]


def test_the_list_wins_over_the_single_variable():
    env = {"GOOGLE_CLIENT_IDS": "mac.apps", "GOOGLE_CLIENT_ID": "web.apps"}
    assert google_client_ids(env) == ["mac.apps"]


def test_nothing_configured_is_an_empty_list():
    assert google_client_ids({}) == []
