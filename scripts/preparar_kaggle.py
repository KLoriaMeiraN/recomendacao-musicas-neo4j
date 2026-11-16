# Prepara os CSVs do Kaggle "Million Song Dataset + Spotify + Last.fm" para o Neo4j
# Uso: python preparar_kaggle.py <pasta_kaggle> <pasta_saida> [--full]
#   sem --full: amostra que cabe no AuraDB Free (200k nós / 400k relacionamentos)
#   com --full: base inteira (Neo4j Desktop / Docker)
import sys, pandas as pd
ORIG, DEST, FULL = sys.argv[1], sys.argv[2], '--full' in sys.argv
LIM_REL, TOP_TAGS, MIN_MUS, CURTIU_MIN, SEGUE_MIN = 380_000, 30, 20, 5, 3
AUDIO = ['danceability', 'energy', 'valence', 'acousticness', 'instrumentalness', 'speechiness', 'liveness']

# Catálogo: músicas, artistas, gênero e tags
mus = pd.read_csv(f'{ORIG}/Music Info.csv').dropna(subset=['track_id', 'name', 'artist'])
mus[AUDIO] = mus[AUDIO].fillna(0)
lst = mus['tags'].fillna('').str.split(r'\s*,\s*')
top = set(lst.explode().loc[lambda s: s != ''].value_counts().index[:None if FULL else TOP_TAGS])
mus['tags'] = lst.apply(lambda t: ';'.join(x for x in t if x in top))
rel_cat = len(mus) + mus['genre'].notna().sum() + mus['tags'].str.count(';').add(mus['tags'].ne('')).sum()

# Histórico: OUVIU real; CURTIU e SEGUE derivados (proxies documentados no README)
his = pd.read_csv(f'{ORIG}/User Listening History.csv', usecols=['track_id', 'user_id', 'playcount'])
his = his[his.track_id.isin(mus.track_id)].merge(mus[['track_id', 'artist']], on='track_id')
cur = his[his.playcount >= CURTIU_MIN]
seg = his.groupby(['user_id', 'artist']).size().reset_index(name='musicas').query('musicas >= @SEGUE_MIN')

# Escolha de usuários: com >= MIN_MUS músicas, sorteados até caber no orçamento de relacionamentos
base = his.groupby('user_id').size().loc[lambda s: s >= MIN_MUS]
custo = base + cur.groupby('user_id').size().reindex(base.index, fill_value=0) + seg.groupby('user_id').size().reindex(base.index, fill_value=0)
if not FULL:
    custo = custo.sample(frac=1, random_state=42)
    custo = custo[custo.cumsum() <= LIM_REL - rel_cat]
his, cur, seg = (d[d.user_id.isin(custo.index)] for d in (his, cur, seg))

# Saída
mus.rename(columns={'name': 'nome', 'artist': 'artista', 'genre': 'genero', 'year': 'ano'})[
    ['track_id', 'nome', 'artista', 'genero', 'tags', 'ano', 'duration_ms', 'tempo', *AUDIO]].to_csv(f'{DEST}/musicas.csv', index=False)
his[['user_id', 'track_id', 'playcount']].to_csv(f'{DEST}/ouviu.csv', index=False)
cur[['user_id', 'track_id']].to_csv(f'{DEST}/curtiu.csv', index=False)
seg.rename(columns={'artist': 'artista'}).to_csv(f'{DEST}/segue.csv', index=False)

nos = len(mus) + mus.artist.nunique() + mus.genre.nunique() + len(top) + len(custo)
rels = rel_cat + len(his) + len(cur) + len(seg)
print(f'Usuarios {len(custo)} | Musicas {len(mus)} | Nos ~{nos} | Relacionamentos ~{rels}')
