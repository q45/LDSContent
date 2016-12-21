CREATE TABLE metadata (
    _id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    key TEXT NOT NULL,
    value TEXT NOT NULL,
    UNIQUE(key)
    );
    
CREATE TABLE language (
    _id INTEGER NOT NULL PRIMARY KEY,
    lds_language_code TEXT NOT NULL,
    iso639_3 TEXT NOT NULL,
    bcp47 TEXT,
    root_library_collection_id INTEGER NOT NULL,
    root_library_collection_external_id TEXT NOT NULL,
    UNIQUE(lds_language_code),
    UNIQUE(iso639_3),
    UNIQUE(root_library_collection_id)
    );
        CREATE INDEX language_bcp47_index ON language (bcp47);
    
CREATE TABLE language_name (
    _id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    language_id INTEGER NOT NULL,
    localization_language_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    UNIQUE(language_id, localization_language_id)
    );

CREATE TABLE library_collection (
    _id INTEGER NOT NULL PRIMARY KEY,
    external_id TEXT NOT NULL,
    library_section_id INTEGER,
    library_section_external_id TEXT,
    position INTEGER NOT NULL,
    title_html TEXT NOT NULL,
    cover_renditions TEXT,
    type_id INTEGER NOT NULL,
    UNIQUE(external_id)
    );
        CREATE INDEX library_collection_library_section_index ON library_collection (library_section_id);

CREATE TABLE library_collection_type (
    _id INTEGER NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    UNIQUE(name)
    );
        INSERT INTO library_collection_type (_id, name) VALUES (1, 'Default');
        INSERT INTO library_collection_type (_id, name) VALUES (2, 'Scriptures');

CREATE TABLE library_section (
    _id INTEGER NOT NULL PRIMARY KEY,
    external_id TEXT NOT NULL,
    library_collection_id INTEGER NOT NULL,
    library_collection_external_id TEXT NOT NULL,
    position INTEGER NOT NULL,
    title TEXT,
    index_title TEXT,
    UNIQUE(external_id)
    );
        CREATE INDEX library_section_library_collection_index ON library_section (library_collection_id);

CREATE TABLE library_item (
    _id INTEGER NOT NULL PRIMARY KEY,
    external_id TEXT NOT NULL,
    library_section_id INTEGER,
    library_section_external_id TEXT,
    position INTEGER NOT NULL,
    title_html TEXT NOT NULL,
    is_obsolete INTEGER NOT NULL,
    item_id INTEGER NOT NULL,
    item_external_id TEXT NOT NULL,
    UNIQUE(external_id)
    );
        CREATE INDEX library_item_library_section_index ON library_item (library_section_id);

CREATE TABLE item (
    _id INTEGER NOT NULL PRIMARY KEY,
    external_id TEXT NOT NULL,
    language_id INTEGER NOT NULL,
    source_id INTEGER NOT NULL,
    platform_id INTEGER NOT NULL,
    uri TEXT NOT NULL,
    title TEXT NOT NULL,
    item_cover_renditions TEXT,
    item_category_id INTEGER NOT NULL,
    version INTEGER NOT NULL,
    is_obsolete INTEGER NOT NULL,
    UNIQUE(external_id)
    );
        CREATE INDEX item_language_index ON item (language_id);
        CREATE INDEX item_platform_index ON item (platform_id);


CREATE TABLE platform (
    _id INTEGER NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    UNIQUE(name)
    );
        INSERT INTO platform (_id, name) VALUES (1, 'All');
        INSERT INTO platform (_id, name) VALUES (2, 'iOS Only');
        INSERT INTO platform (_id, name) VALUES (3, 'Android Only');

CREATE TABLE item_category (
    _id INTEGER NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    UNIQUE(name)
    );

CREATE TABLE source (
    _id INTEGER NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    type_id INTEGER NOT NULL,
    UNIQUE(name)
    );

CREATE TABLE stopword (
    _id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    language_id INTEGER NOT NULL REFERENCES language(_id),
    word TEXT NOT NULL,
    UNIQUE(language_id, word)
    );

CREATE TABLE subitem_metadata (
    _id INTEGER NOT NULL PRIMARY KEY,
    item_id INTEGER NOT NULL REFERENCES item(_id),
    subitem_id INTEGER NOT NULL,
    doc_id TEXT NOT NULL,
    doc_version INTEGER NOT NULL,
    UNIQUE(item_id, subitem_id)
    );
        CREATE INDEX subitem_metadata_doc_id_index ON subitem_metadata (doc_id);
