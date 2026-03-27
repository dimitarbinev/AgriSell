import pandas as pd
import os

EXCEL_PATH = r"c:\Users\Deo\Documents\GitHub\Hack tues 12\Domashno-Gang\Ai\Prices_of_agricultural_products_by_year.xlsx"

try:
    df = pd.read_excel(EXCEL_PATH, header=None, skiprows=3)
    df.columns = ["code", "name", "unit", "Q1", "Q2", "Q3", "Q4", "annual"]
    
    with open("excel_report.txt", "w", encoding="utf-8") as f:
        for i in range(25, 40):
            row = df.iloc[i]
            f.write(f"Index {i}: {row['name']} | Q1: {row['Q1']}, Q2: {row['Q2']}, Q3: {row['Q3']}, Q4: {row['Q4']}, Annual: {row['annual']}\n")
    
        f.write("\nSearching for 'от открити площи':\n")
        matches = df[df["name"].str.contains("от открити площи", na=False)]
        for idx, row in matches.iterrows():
            f.write(f"Index {idx}: {row['name']} | Q1: {row['Q1']}, Q2: {row['Q2']}, Q3: {row['Q3']}, Q4: {row['Q4']}, Annual: {row['annual']}\n")
    print("Done writing excel_report.txt")
except Exception as e:
    print(f"Error: {e}")
