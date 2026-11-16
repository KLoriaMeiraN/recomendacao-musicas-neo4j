// 02 - Carga dos CSVs direto do GitHub (raw)

// Músicas + Artistas + Gêneros (generos separados por ';', como as tags do Kaggle)
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/KLoriaMeiraN/recomendacao-musicas-neo4j/refs/heads/main/data/musicas.csv' AS row
MERGE (m:Musica {track_id: row.track_id})
SET m.nome = row.nome, m.ano = toInteger(row.ano)
MERGE (a:Artista {nome: row.artista})
MERGE (m)-[:INTERPRETADA_POR]->(a)
FOREACH (g IN split(row.generos, ';') |
  MERGE (gen:Genero {nome: trim(g)})
  MERGE (m)-[:DO_GENERO]->(gen));

// Usuários
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/KLoriaMeiraN/recomendacao-musicas-neo4j/refs/heads/main/data/usuarios.csv' AS row
MERGE (u:Usuario {id: row.user_id})
SET u.nome = row.nome, u.cidade = row.cidade;

// OUVIU (propriedade: nº de execuções)
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/KLoriaMeiraN/recomendacao-musicas-neo4j/refs/heads/main/data/ouviu.csv' AS row
MATCH (u:Usuario {id: row.user_id})
MATCH (m:Musica {track_id: row.track_id})
MERGE (u)-[r:OUVIU]->(m)
SET r.vezes = toInteger(row.playcount);

// CURTIU (propriedade: data)
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/KLoriaMeiraN/recomendacao-musicas-neo4j/refs/heads/main/data/curtiu.csv' AS row
MATCH (u:Usuario {id: row.user_id})
MATCH (m:Musica {track_id: row.track_id})
MERGE (u)-[r:CURTIU]->(m)
SET r.data = date(row.data);

// SEGUE (usuário -> artista)
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/KLoriaMeiraN/recomendacao-musicas-neo4j/refs/heads/main/data/segue.csv' AS row
MATCH (u:Usuario {id: row.user_id})
MATCH (a:Artista {nome: row.artista})
MERGE (u)-[:SEGUE]->(a);

// Conferência: visual do schema (print para o README)
CALL db.schema.visualization();
