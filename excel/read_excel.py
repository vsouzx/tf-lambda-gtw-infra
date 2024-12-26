import pandas as pd
import requests
import json
import os

def enviar_dados_excel(file_path):
    headers = {
        'Content-Type': 'application/json'
    }

    try:
        # Tentar obter o valor da variável de ambiente
        url = os.environ['api_gateway_url']
    except KeyError:
    # Lançar uma exceção personalizada se a variável não estiver configurada
        raise EnvironmentError("A variável de ambiente 'api_gateway_url' não está configurada.")

    try:
        df = pd.read_excel(file_path)
    except Exception as e:
        print(f"Erro ao ler o arquivo Excel: {e}")
        return

    required_columns = ['num_funl_cola', 'cod_ciclo', 'nota_ini']
    for column in required_columns:
        if column not in df.columns:
            print(f"Erro: coluna obrigatória '{column}' não encontrada no Excel.")
            return

    for index, row in df.iterrows():
        body = {
            "funcional": str(row['num_funl_cola']),  
            "cod_ciclo": int(row['cod_ciclo']),
            "nota_ini": int(row['nota_ini'])
        }

        try:
            response = requests.post(url, headers=headers, data=json.dumps(body))
            if response.status_code == 201:
                print(f"Linha {index + 1}: Envio bem-sucedido.")
            else:
                print(f"Linha {index + 1}: Falha no envio - Status {response.status_code}. Resposta: {response.text}")
        except Exception as e:
            print(f"Linha {index + 1}: Erro ao enviar dados - {e}")

if __name__ == "__main__":
    file_path = "./comites.xls"  
    enviar_dados_excel(file_path)
