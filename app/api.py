from fastapi import FastAPI, Query
from mangum import Mangum

app = FastAPI(title="Challenge API", version="1.0.0")

@app.get("/health") # rota de verificação simples
def health():
    return {"status": "ok"}

@app.get("/health2") # rota de verificação simples
def health():
    return {"status": "ok"}

@app.get("/hello")   # rota de exemplo com hello e o nome como query parameter
def hello(name: str = Query("world", min_length=1, max_length=50)):
    return {"message": f"Hello, {name}!"}

handler = Mangum(app) # handler para AWS Lambda via API Gateway (ASGI adapter)

