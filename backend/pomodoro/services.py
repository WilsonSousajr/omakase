"""Ownership rules for sessions, reached through the hierarchy without
importing another app (the independence contract)."""


def time_block_owner(block):
    """The user a time block belongs to: its task's, or its study block's.

    >>> time_block_owner(block) == request.user
    """
    if block.task_id:
        return block.task.user
    return block.study_block.discipline.semester.user
