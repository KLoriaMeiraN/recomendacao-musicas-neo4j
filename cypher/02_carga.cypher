// 02 - Carga dos CSVs
// No Neo4j Browser, defina antes a pasta base dos arquivos:
//   Aura:    :param base => 'https://raw.githubusercontent.com/<seu-usuario>/<seu-repo>/main/data/'
//   Desktop: :param base => 'file:///'   (CSVs copiados para a pasta import do DBMS)

// Músicas + Artistas + Gêneros (generos vem separado por ';', como as tags do Kaggle)
LOAD CSV WITH HEADERS FROM $base + 'musicas.csv' AS row
MERGE (m:Musica {track_id: row.track_id})
SET m.nome = row.nome, m.ano = toInteger(row.ano)
MERGE (a:Artista {nome: row.artista})
MERGE (m)-[:INTERPRETADA_POR]->(a)
FOREACH (g IN split(row.generos, ';') |
  MERGE (gen:Genero {nome: trim(g)})
  MERGE (m)-[:DO_GENERO]->(gen));

// Usuários
LOAD CSV WITH HEADERS FROM $base + 'usuarios.csv' AS row
MERGE (u:Usuario {id: row.user_id})
SET u.nome = row.nome, u.cidade = row.cidade;

// Interação OUVIU (aresta com propriedade: nº de execuções)
LOAD CSV WITH HEADERS FROM $base + 'ouviu.csv' AS row
MATCH (u:Usuario {id: row.user_id})
MATCH (m:Musica {track_id: row.track_id})
MERGE (u)-[r:OUVIU]->(m)
SET r.vezes = toInteger(row.playcount);

// Interação CURTIU (aresta com propriedade: data)
LOAD CSV WITH HEADERS FROM $base + 'curtiu.csv' AS row
MATCH (u:Usuario {id: row.user_id})
MATCH (m:Musica {track_id: row.track_id})
MERGE (u)-[r:CURTIU]->(m)
SET r.data = date(row.data);

// Interação SEGUE (usuário -> artista)
LOAD CSV WITH HEADERS FROM $base + 'segue.csv' AS row
MATCH (u:Usuario {id: row.user_id})
MATCH (a:Artista {nome: row.artista})
MERGE (u)-[:SEGUE]->(a);

// Conferência: visual do schema inferido (print para o README)
CALL db.schema.visualization();
