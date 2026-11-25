/// What the export dialog of a board answers: the server path of the archive
/// (empty for the server's export folder) and what goes into it.
typedef KanbanExportOptions = ({String output, bool attachments, bool logs});

/// What the import dialog answers: the server-side archive, the slug for the
/// new board (empty to keep the archive's) and whether to open it afterwards.
typedef KanbanImportOptions = ({String archive, String slug, bool open});
