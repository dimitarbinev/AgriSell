import os
from dotenv import load_dotenv
from typing import List, Literal
from pydantic import BaseModel, Field
from langchain_openai import ChatOpenAI
from langchain_core.prompts import ChatPromptTemplate

# Зареждаме .env файла за API ключа
load_dotenv()

# 1. Дефинираме структурата на отговора (за максимална стабилност)
class ProduceClassification(BaseModel):
    item: str = Field(description="Името на продукта на български")
    category: Literal["зеленчук", "плод", "месо", "млечен продукт", "друго"] = Field(
        description="Категорията, към която принадлежи продукта"
    )
    confidence: float = Field(description="Увереност на модела от 0 до 1")

# 2. Инициализираме модела
# Можеш да ползваш GPT-4o-mini - той е перфектният "мини" модел за това
llm = ChatOpenAI(model="gpt-4o-mini", temperature=0).with_structured_output(ProduceClassification)

# 3. Дефинираме Промпта
prompt = ChatPromptTemplate.from_messages([
    ("system", "Ти си експерт по хранителни стоки. Твоята задача е да класифицираш продукти на български език в правилни категории."),
    ("human", "Класифицирай следния продукт: {product}")
])

# 4. Сглобяваме веригата (Chain)
chain = prompt | llm

# --- Тестване ---
test_items = ["краставица", "кисело мляко", "свински врат", "банан", "сирене Дунавия"]

print(f"{'Продукт':<20} | {'Категория':<15} | {'Сигурност'}")
print("-" * 50)

for item in test_items:
    result = chain.invoke({"product": item})
    print(f"{result.item:<20} | {result.category:<15} | {result.confidence:.2f}")
