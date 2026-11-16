// 01 - "Schema" do grafo: unicidade e índices (rodar ANTES da carga)
CREATE CONSTRAINT usuario_id  IF NOT EXISTS FOR (u:Usuario) REQUIRE u.id IS UNIQUE;
CREATE CONSTRAINT musica_id   IF NOT EXISTS FOR (m:Musica)  REQUIRE m.track_id IS UNIQUE;
CREATE CONSTRAINT artista_nome IF NOT EXISTS FOR (a:Artista) REQUIRE a.nome IS UNIQUE;
CREATE CONSTRAINT genero_nome IF NOT EXISTS FOR (g:Genero)  REQUIRE g.nome IS UNIQUE;
CREATE INDEX musica_nome IF NOT EXISTS FOR (m:Musica) ON (m.nome);
CREATE CONSTRAINT tag_nome    IF NOT EXISTS FOR (t:Tag)     REQUIRE t.nome IS UNIQUE;
