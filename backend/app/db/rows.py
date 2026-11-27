from typing import Any

from sqlalchemy import Table
from sqlalchemy.engine import Connection, Row


def update_row(db: Connection, table: Table, row: Row, **values: Any) -> Row:
    """Update a previously loaded row and return its persisted values."""
    changes = {
        name: value for name, value in values.items() if value != getattr(row, name)
    }
    if not changes:
        return row
    statement = (
        table.update().where(table.c.id == row.id).values(**changes).returning(table)
    )
    return db.execute(statement).one()
