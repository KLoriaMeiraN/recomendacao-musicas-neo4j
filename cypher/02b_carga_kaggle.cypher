// 02b - Carga da base Kaggle (Million Song Dataset + Spotify + Last.fm)
// Pré-requisito: CSVs gerados por scripts/preparar_kaggle.py e enviados para data_kaggle/ no GitHub
// Rode um bloco por vez. Se o Aura reclamar de "implicit transaction", coloque :auto antes do LOAD CSV.

// 0. Limpar a amostra anterior (se já carregou a base sintética)
MATCH (n) CALL (n) { DETACH DELETE n } IN TRANSACTIONS OF 5000 ROWS;

// 1. Músicas + atributos de áudio + Artista + Gênero + Tags
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/KLoriaMeiraN/recomendacao-musicas-neo4j/refs/heads/main/data_kaggle/musicas.csv' AS row
CALL (row) {
  MERGE (m:Musica {track_id: row.track_id})
  SET m.nome = row.nome, m.ano = toInteger(row.ano), m.duracao_ms = toInteger(row.duration_ms),
      m.tempo = toFloat(row.tempo), m.energy = toFloat(row.energy), m.danceability = toFloat(row.danceability),
      m.valence = toFloat(row.valence),
      m.audio = [toFloat(row.danceability), toFloat(row.energy), toFloat(row.valence), toFloat(row.acousticness),
                 toFloat(row.instrumentalness), toFloat(row.speechiness), toFloat(row.liveness)]
  MERGE (a:Artista {nome: row.artista})
  MERGE (m)-[:INTERPRETADA_POR]->(a)
  FOREACH (g IN CASE WHEN row.genero IS NULL THEN [] ELSE [row.genero] END |
    MERGE (gen:Genero {nome: g}) MERGE (m)-[:DO_GENERO]->(gen))
  FOREACH (t IN CASE WHEN row.tags IS NULL THEN [] ELSE split(row.tags, ';') END |
    MERGE (tg:Tag {nome: t}) MERGE (m)-[:TEM_TAG]->(tg))
} IN TRANSACTIONS OF 2000 ROWS;

// 2. Usuários + OUVIU (dado real de execuções)
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/KLoriaMeiraN/recomendacao-musicas-neo4j/refs/heads/main/data_kaggle/ouviu.csv' AS row
CALL (row) {
  MERGE (u:Usuario {id: row.user_id})
  WITH u, row MATCH (m:Musica {track_id: row.track_id})
  MERGE (u)-[r:OUVIU]->(m) SET r.vezes = toInteger(row.playcount)
} IN TRANSACTIONS OF 5000 ROWS;

// 3. CURTIU (derivado: ouviu 5+ vezes)
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/KLoriaMeiraN/recomendacao-musicas-neo4j/refs/heads/main/data_kaggle/curtiu.csv' AS row
CALL (row) {
  MATCH (u:Usuario {id: row.user_id}), (m:Musica {track_id: row.track_id})
  MERGE (u)-[:CURTIU]->(m)
} IN TRANSACTIONS OF 5000 ROWS;

// 4. SEGUE (derivado: ouviu 3+ músicas do artista)
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/KLoriaMeiraN/recomendacao-musicas-neo4j/refs/heads/main/data_kaggle/segue.csv' AS row
CALL (row) {
  MATCH (u:Usuario {id: row.user_id}), (a:Artista {nome: row.artista})
  MERGE (u)-[r:SEGUE]->(a) SET r.musicas = toInteger(row.musicas)
} IN TRANSACTIONS OF 5000 ROWS;

// 5. Conferência
MATCH (n) RETURN labels(n)[0] AS label, count(*) AS total ORDER BY total DESC;
CALL db.schema.visualization();
