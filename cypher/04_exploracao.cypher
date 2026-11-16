// 04 - Exploração: perfis de usuários e características da base
// Objetivo: definir os moldes do modelo de recomendação. Rodar uma query por vez.

// E1. Densidade da matriz usuário x música
// -> Muito esparsa? Filtragem colaborativa pura sofre; considerar modelo híbrido.
MATCH (u:Usuario) WITH count(u) AS usuarios
MATCH (m:Musica)  WITH usuarios, count(m) AS musicas
MATCH ()-[r:OUVIU]->() WITH usuarios, musicas, count(r) AS escutas
RETURN usuarios, musicas, escutas,
       round(1.0 * escutas / usuarios, 1) AS musicas_por_usuario,
       round(100.0 * escutas / (usuarios * musicas), 4) AS densidade_pct;

// E2. Atividade dos usuários (quantas músicas cada um ouviu)
// -> Define o mínimo de histórico para usar colaborativa vs. conteúdo.
MATCH (u:Usuario)-[:OUVIU]->() WITH u, count(*) AS n
RETURN CASE WHEN n < 30 THEN '20-29' WHEN n < 50 THEN '30-49' WHEN n < 100 THEN '50-99' ELSE '100+' END AS faixa,
       count(*) AS usuarios, min(n) AS a_partir_de ORDER BY a_partir_de;

// E3. Popularidade das músicas (cauda longa e cold start de itens)
// -> Muitas músicas sem ouvintes = precisam de recomendação por conteúdo (áudio/tags).
MATCH (m:Musica) WITH m, COUNT { (m)<-[:OUVIU]-() } AS ouvintes
RETURN CASE WHEN ouvintes = 0 THEN '0 (sem ouvintes)' WHEN ouvintes < 5 THEN '1-4' WHEN ouvintes < 20 THEN '5-19' ELSE '20+' END AS faixa,
       count(*) AS musicas, min(ouvintes) AS a_partir_de ORDER BY a_partir_de;

// E4. Intensidade de escuta (distribuição de playcount)
// -> Define peso do feedback implícito (ex.: log(vezes)) e o corte de "curtiu".
MATCH ()-[o:OUVIU]->()
RETURN min(o.vezes) AS minimo, percentileCont(o.vezes, 0.5) AS mediana,
       percentileCont(o.vezes, 0.9) AS p90, max(o.vezes) AS maximo, round(avg(o.vezes), 1) AS media;

// E5. Cobertura de metadados
// -> Quantas músicas têm gênero/tag para alimentar o modelo de conteúdo.
MATCH (m:Musica)
RETURN count(m) AS musicas,
       sum(CASE WHEN EXISTS { (m)-[:DO_GENERO]->() } THEN 1 ELSE 0 END) AS com_genero,
       sum(CASE WHEN EXISTS { (m)-[:TEM_TAG]->() } THEN 1 ELSE 0 END) AS com_tag;

// E6. Alcance de cada gênero (usuários que ouvem cada modalidade)
MATCH (u:Usuario)-[o:OUVIU]->(:Musica)-[:DO_GENERO]->(g:Genero)
RETURN g.nome AS genero, count(DISTINCT u) AS usuarios, sum(o.vezes) AS execucoes
ORDER BY usuarios DESC;

// E7. Gênero dominante de cada usuário (fãs de cada modalidade)
// fidelidade = fatia das execuções do usuário no seu gênero principal
MATCH (u:Usuario)-[o:OUVIU]->(:Musica)-[:DO_GENERO]->(g:Genero)
WITH u, g.nome AS genero, sum(o.vezes) AS p
WITH u, collect({g: genero, p: p}) AS gs, sum(p) AS total
WITH reduce(mx = {g: '', p: 0}, x IN gs | CASE WHEN x.p > mx.p THEN x ELSE mx END) AS top, total, size(gs) AS n_generos
RETURN top.g AS genero_dominante, count(*) AS usuarios,
       round(avg(1.0 * top.p / total), 2) AS fidelidade_media, round(avg(n_generos), 1) AS generos_por_usuario
ORDER BY usuarios DESC;

// E8. Especialistas x ecléticos
// -> Especialista: recomendar dentro do gênero (conteúdo). Eclético: colaborativa/descoberta.
MATCH (u:Usuario)-[o:OUVIU]->(:Musica)-[:DO_GENERO]->(g:Genero)
WITH u, g, sum(o.vezes) AS p
WITH u, max(p) AS top, sum(p) AS total
WITH 1.0 * top / total AS fidelidade
RETURN CASE WHEN fidelidade >= 0.7 THEN 'especialista (>=70% em 1 gênero)'
            WHEN fidelidade >= 0.4 THEN 'misto' ELSE 'eclético (<40% em 1 gênero)' END AS perfil,
       count(*) AS usuarios ORDER BY usuarios DESC;

// E9. Amplitude: quantos gêneros cada usuário ouve (inclui "gosta de todos")
MATCH (g:Genero) WITH count(g) AS total_generos
MATCH (u:Usuario)-[:OUVIU]->(:Musica)-[:DO_GENERO]->(g:Genero)
WITH total_generos, u, count(DISTINCT g) AS n
RETURN n AS generos_ouvidos, total_generos, count(u) AS usuarios ORDER BY generos_ouvidos DESC;

// E10. Afinidade entre gêneros (co-escuta pelos mesmos usuários)
// -> Base para recomendações "fora da bolha" e para embeddings.
MATCH (u:Usuario)-[:OUVIU]->(:Musica)-[:DO_GENERO]->(g:Genero)
WITH u, collect(DISTINCT g.nome) AS gs
UNWIND gs AS g1 UNWIND gs AS g2
WITH g1, g2 WHERE g1 < g2
RETURN g1 AS genero_a, g2 AS genero_b, count(*) AS usuarios_em_comum
ORDER BY usuarios_em_comum DESC LIMIT 20;

// E11. Assinatura de áudio por gênero
// -> Se os gêneros têm perfis distintos, o vetor 'audio' é bom atributo para o modelo.
MATCH (m:Musica)-[:DO_GENERO]->(g:Genero)
RETURN g.nome AS genero, count(m) AS musicas,
       round(avg(m.energy), 2) AS energia, round(avg(m.danceability), 2) AS dancabilidade,
       round(avg(m.valence), 2) AS valencia, round(avg(m.tempo)) AS bpm
ORDER BY energia DESC;
