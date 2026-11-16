// 03 - Queries de negócio
// Defina o usuário alvo:  :param usuario => 'U01'

// Q1. Filtragem colaborativa: o que ouvem as pessoas que ouvem o mesmo que eu?
MATCH (eu:Usuario {id: $usuario})-[:OUVIU]->(:Musica)<-[:OUVIU]-(outro:Usuario)-[o:OUVIU]->(rec:Musica)
WHERE outro <> eu AND NOT EXISTS { (eu)-[:OUVIU]->(rec) }
RETURN rec.nome AS recomendacao, count(DISTINCT outro) AS vizinhos, sum(o.vezes) AS execucoes
ORDER BY vizinhos DESC, execucoes DESC LIMIT 10;

// Q2. Por conteúdo: músicas dos gêneros que mais escuto (peso = execuções)
MATCH (eu:Usuario {id: $usuario})-[o:OUVIU]->(:Musica)-[:DO_GENERO]->(g:Genero)
WITH eu, g, sum(o.vezes) AS peso
MATCH (g)<-[:DO_GENERO]-(rec:Musica)
WHERE NOT EXISTS { (eu)-[:OUVIU]->(rec) }
RETURN rec.nome AS recomendacao, collect(g.nome) AS generos, sum(peso) AS score
ORDER BY score DESC LIMIT 10;

// Q3. Artistas que sigo: faixas deles que ainda não ouvi
MATCH (eu:Usuario {id: $usuario})-[:SEGUE]->(a:Artista)<-[:INTERPRETADA_POR]-(rec:Musica)
WHERE NOT EXISTS { (eu)-[:OUVIU]->(rec) }
RETURN a.nome AS artista, rec.nome AS recomendacao;

// Q4. Usuários mais parecidos comigo (Jaccard calculado em Cypher puro, sem GDS)
MATCH (eu:Usuario {id: $usuario})-[:OUVIU]->(m:Musica)<-[:OUVIU]-(outro:Usuario)
WITH eu, outro, count(m) AS comum
MATCH (eu)-[:OUVIU]->(m1) WITH eu, outro, comum, count(m1) AS n1
MATCH (outro)-[:OUVIU]->(m2) WITH outro, comum, n1, count(m2) AS n2
RETURN outro.nome AS usuario, comum, round(toFloat(comum) / (n1 + n2 - comum), 2) AS jaccard
ORDER BY jaccard DESC LIMIT 5;

// Q5. Cold start (usuário novo): mais ouvidas e mais curtidas
MATCH (m:Musica)
OPTIONAL MATCH (m)<-[o:OUVIU]-()
WITH m, coalesce(sum(o.vezes), 0) AS execucoes
OPTIONAL MATCH (m)<-[c:CURTIU]-()
RETURN m.nome AS musica, execucoes, count(c) AS curtidas
ORDER BY curtidas DESC, execucoes DESC LIMIT 10;

// ---------- GDS (somente se a instância tiver Graph Data Science) ----------
// Projeção não direcionada Usuario—Musica com peso
CALL gds.graph.project('musicas', ['Usuario', 'Musica'],
  {OUVIU: {orientation: 'UNDIRECTED', properties: 'vezes'}});

// Q6. Similaridade entre usuários (Node Similarity)
CALL gds.nodeSimilarity.stream('musicas', {relationshipWeightProperty: 'vezes'})
YIELD node1, node2, similarity
WITH gds.util.asNode(node1) AS a, gds.util.asNode(node2) AS b, similarity
WHERE a:Usuario AND a.id = $usuario
RETURN b.nome AS similar, round(similarity, 3) AS sim ORDER BY sim DESC LIMIT 5;

// Q7. PageRank: músicas mais "centrais" na rede de escuta
CALL gds.pageRank.stream('musicas', {relationshipWeightProperty: 'vezes'})
YIELD nodeId, score
WITH gds.util.asNode(nodeId) AS n, score WHERE n:Musica
RETURN n.nome AS musica, round(score, 3) AS pagerank ORDER BY pagerank DESC LIMIT 10;

// Q8. Comunidades de gosto (Louvain)
CALL gds.louvain.stream('musicas', {relationshipWeightProperty: 'vezes'})
YIELD nodeId, communityId
WITH communityId, gds.util.asNode(nodeId) AS n
RETURN communityId,
  [x IN collect(n) WHERE x:Usuario | x.nome] AS usuarios,
  [x IN collect(n) WHERE x:Musica | x.nome][..5] AS amostra_musicas
ORDER BY size(usuarios) DESC;

// Limpeza da projeção
CALL gds.graph.drop('musicas');
