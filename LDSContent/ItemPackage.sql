CREATE TABLE metadata (
    _id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    key TEXT NOT NULL,
    value TEXT NOT NULL,
    UNIQUE(key)
    );

CREATE TABLE subitem (
    _id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    uri TEXT NOT NULL,
    position INTEGER NOT NULL,
    title_html TEXT NOT NULL,
    title TEXT NOT NULL,
    web_url TEXT NOT NULL,
    doc_id TEXT NOT NULL,
    doc_version INTEGER NOT NULL,
    content_type INTEGER NOT NULL DEFAULT 1,
    UNIQUE(uri),
    UNIQUE(position)
    );
        CREATE INDEX subitem_doc_id_index ON subitem (doc_id);

CREATE VIRTUAL TABLE subitem_content_fts USING fts4(subitem_id, content_html, tokenize=HTMLTokenizer %1$@);

CREATE VIEW subitem_content AS
    SELECT rowid AS _id, c0subitem_id AS subitem_id, c1content_html AS content_html FROM subitem_content_fts_content;

CREATE TABLE related_content_item (
    _id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    subitem_id INTEGER NOT NULL,
    ref_id TEXT NOT NULL,
    label_html TEXT NOT NULL,
    origin_id TEXT NOT NULL,
    content_html TEXT NOT NULL,
    word_offset INTEGER NOT NULL,
    byte_location INTEGER NOT NULL,
    UNIQUE(subitem_id, byte_location)
    );
        CREATE INDEX related_content_item_subitem_index ON related_content_item (subitem_id);

CREATE TABLE related_audio_voice (
    _id INTEGER NOT NULL PRIMARY KEY,
    name TEXT NOT NULL
);
        INSERT INTO related_audio_voice (_id, name) VALUES (1, 'Male');
        INSERT INTO related_audio_voice (_id, name) VALUES (2, 'Female');

CREATE TABLE related_audio_item (
    _id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    subitem_id INTEGER NOT NULL,
    media_url TEXT NOT NULL,
    file_size INTEGER NOT NULL,
    duration INTEGER NOT NULL,
    related_audio_voice_id INTEGER REFERENCES related_audio_voice(_id)
    );
        CREATE INDEX related_audio_item_subitem_index ON related_audio_item (subitem_id);

CREATE TABLE related_video_item (
    _id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    subitem_id INTEGER NOT NULL,
    poster_url TEXT,
    video_id TEXT NOT NULL,
    title TEXT NOT NULL
    );
        CREATE INDEX related_video_item_subitem_index ON related_video_item (subitem_id);

CREATE TABLE related_video_item_source (
    _id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    media_url TEXT NOT NULL,
    type TEXT NOT NULL,
    width INTEGER,
    height INTEGER,
    file_size INTEGER,
    related_video_item_id INTEGER REFERENCES related_video_item(_id)
    );

CREATE TABLE nav_collection (
    _id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    nav_section_id INTEGER,
    position INTEGER NOT NULL,
    image_renditions TEXT,
    title_html TEXT NOT NULL,
    subtitle TEXT,
    uri TEXT NOT NULL,
    UNIQUE(nav_section_id, position),
    UNIQUE(uri)
    );
        CREATE INDEX nav_collection_nav_section_index ON nav_collection (nav_section_id);

CREATE TABLE nav_collection_index_entry (
    _id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    nav_collection_id INTEGER NOT NULL,
    position INTEGER NOT NULL,
    title TEXT NOT NULL,
    list_index INTEGER NOT NULL,
    section INTEGER NOT NULL,
    row INTEGER NOT NULL,
    UNIQUE(nav_collection_id, position)
    );
        CREATE INDEX nav_collection_index_entry_nav_collection_index ON nav_collection_index_entry (nav_collection_id);

CREATE TABLE nav_section (
    _id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    nav_collection_id INTEGER NOT NULL,
    position INTEGER NOT NULL,
    indent_level INTEGER NOT NULL,
    title TEXT,
    UNIQUE(nav_collection_id, position)
    );
        CREATE INDEX nav_section_nav_collection_index ON nav_section (nav_collection_id);

CREATE TABLE nav_item (
    _id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    nav_section_id INTEGER NOT NULL,
    position INTEGER NOT NULL,
    image_renditions TEXT,
    title_html TEXT NOT NULL,
    subtitle TEXT,
    preview TEXT,
    uri TEXT NOT NULL,
    subitem_id INTEGER NOT NULL,
    UNIQUE(nav_section_id, position),
    UNIQUE(uri),
    UNIQUE(subitem_id)
    );
        CREATE INDEX nav_item_nav_section_index ON nav_item (nav_section_id);

CREATE TABLE paragraph_metadata (
    _id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    subitem_id INTEGER NOT NULL REFERENCES subitem(_id),
    paragraph_id TEXT NOT NULL,
    paragraph_aid TEXT NOT NULL,
    verse_number TEXT,
    start_index INTEGER NOT NULL,
    end_index INTEGER NOT NULL,
    UNIQUE(subitem_id, paragraph_id)
    );
        CREATE INDEX paragraph_metadata_paragraph_aid_idx ON paragraph_metadata (paragraph_aid);

CREATE TABLE author (
    _id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    given_name TEXT NOT NULL,
    family_name TEXT NOT NULL,
    image_renditions TEXT,
    UNIQUE(given_name, family_name)
    );
        CREATE INDEX author_given_name_idx ON author (given_name);
        CREATE INDEX author_family_name_idx ON author (family_name);

CREATE TABLE role (
    _id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    position INTEGER NOT NULL,
    UNIQUE(NAME)
    );
        CREATE INDEX role_name_idx ON role (name);

CREATE TABLE subitem_author (
    _id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    subitem_id INTEGER NOT NULL REFERENCES subitem(_id),
    author_id INTEGER NOT NULL REFERENCES author(_id),
    UNIQUE(subitem_id, author_id)
    );

CREATE TABLE author_role (
    _id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    author_id INTEGER NOT NULL REFERENCES author(_id),
    role_id INTEGER NOT NULL REFERENCES role(_id),
    position INTEGER NOT NULL,
    UNIQUE(author_id, role_id)
    );

CREATE TABLE topic (
    _id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    UNIQUE(name)
    );
        CREATE INDEX topic_name_idx ON topic (name);

CREATE TABLE subitem_topic (
    _id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    subitem_id INTEGER NOT NULL REFERENCES subitem(_id),
    topic_id INTEGER NOT NULL REFERENCES topic(_id),
    UNIQUE(subitem_id, topic_id)
    );
