import json
import boto3
import os
from decimal import Decimal
from datetime import datetime
from boto3.dynamodb.conditions import Attr

try:
    # Tentar obter o valor da variável de ambiente
    table_name = os.environ['DYNAMODB_TABLE']
except KeyError:
    # Lançar uma exceção personalizada se a variável não estiver configurada
    raise EnvironmentError("A variável de ambiente 'DYNAMODB_TABLE' não está configurada.")

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    print(event)

    http_method = event['httpMethod']

    if http_method == 'POST':
        return criar_avaliacao(event)
    if http_method == 'GET':
        return listar_avaliacoes(event)
    if http_method == 'PUT':
        return atualizar_avaliacao(event)
    else:
        return {
            'statusCode': 405,
            'body': json.dumps('Method not allowed')
        }
    
#service
def criar_avaliacao(event):
    body = json.loads(event['body'])
    item={
        'funcional': body['funcional'],
        'cod_ciclo': body['cod_ciclo'],
        'status_avli': 'pendente',
        'nota_ini': body['nota_ini'],
        'nota_fim': None,
        'comentario': None,
        'data_atualizacao': str(datetime.now())
    }

    inserir_avaliacao(item)

    return {
            'statusCode': 201,
            'body': json.dumps(item, default=decimal_default)
        }  

def atualizar_avaliacao(event):
    body = json.loads(event['body'])

    response = update_avaliacao(body)

    item = response['Attributes']

    return {
            'statusCode': 201,
            'body': json.dumps(item, default=decimal_default)
        }    

def listar_avaliacoes(event):
    query_params = event.get('queryStringParameters', {})
    if not query_params:
        items = find_all()
        return {
            'statusCode': 200,
            'body': json.dumps(items, default=decimal_default)
        }

    filter_expression = None

    query_handlers = {
        'notas': lambda value: Attr('nota_ini').is_in(value.split(',')),
        'status_avli': lambda value: Attr('status_avli').is_in(value.split(',')),
        'cod_ciclo': lambda value: Attr('cod_ciclo').eq(int(value))
    }

    try:
        for key, value in query_params.items():
            if key not in query_handlers:
                return {
                    'statusCode': 400,
                    'body': json.dumps(f'Unsupported query parameter: {key}')
                }

            current_expression = query_handlers[key](value)

            if filter_expression is None:
                filter_expression = current_expression
            else:
                filter_expression &= current_expression

        response = find_by_filter_expression(filter_expression)

        return {
            'statusCode': 200,
            'body': json.dumps(response['Items'], default=decimal_default)
        }
    except ValueError as e:
        return {
            'statusCode': 400,
            'body': json.dumps(str(e))
        }

def find_all():
    response = findAll()
    return response['Items']

#dynamo repository
def inserir_avaliacao(item):
    table.put_item(Item=item)

def update_avaliacao(body):
    update_expression = "SET "
    expression_attribute_values = {}

    for key, value in body.items():
        if key not in ['funcional', 'cod_ciclo']:
            update_expression += f"{key} = :{key}, "
            expression_attribute_values[f":{key}"] = value

    update_expression += "data_atualizacao = :data_atualizacao"
    expression_attribute_values["data_atualizacao"] = str(datetime.now())

    return table.update_item(
        Key={
            'funcional': body['funcional'],
            'cod_ciclo': body['cod_ciclo']
        },
        UpdateExpression=update_expression,
        ExpressionAttributeValues=expression_attribute_values, 
        ReturnValues="ALL_NEW"
    )


def findAll():
    return table.scan()

def find_by_filter_expression(filter_expression):
    return table.scan(FilterExpression=filter_expression)
    
#decimal utils
def decimal_default(obj):
    if isinstance(obj, Decimal):
        try:
            return int(obj) 
        except (ValueError, OverflowError):
            return float(obj) 
    raise TypeError(f"Object of type {obj.__class__.__name__} is not JSON serializable")
