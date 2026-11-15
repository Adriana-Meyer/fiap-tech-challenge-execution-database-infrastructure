# fiap-tech-challenge-execution-database-infrastructure

Infraestrutura do banco de dados do **Execution Service** (fila de execução dos serviços da oficina) do Tech Challenge — FIAP Pós-Tech, Arquitetura de Software, turma 15SOAT. Provisiona, via Terraform, a tabela **Amazon DynamoDB** do serviço. Diferente do OS, do Billing e do Inventory, o Execution não usa banco relacional.

| Repositório | Papel |
|---|---|
| [`fiap-tech-challenge-execution-service`](https://github.com/Adriana-Meyer/fiap-tech-challenge-execution-service) | Código do serviço |
| [`fiap-tech-challenge-execution-infrastructure`](https://github.com/Adriana-Meyer/fiap-tech-challenge-execution-infrastructure) | Namespace e fila de comandos do serviço |
| **fiap-tech-challenge-execution-database-infrastructure** (este) | Tabela DynamoDB `execution-orders` |
| [`fiap-tech-challenge-os-infrastructure`](https://github.com/Adriana-Meyer/fiap-tech-challenge-os-infrastructure) | VPC, cluster EKS, New Relic e a mensageria compartilhada da saga |

## O que este repositório cria

| Recurso | Detalhe |
|---|---|
| `aws_dynamodb_table` | `execution-orders`: chave de partição `serviceOrderId` (string), cobrança sob demanda (`PAY_PER_REQUEST`) |

É tudo: não há instância, rede, security group nem senha.

## Por que DynamoDB

O Execution guarda a **fila de trabalho dos mecânicos**: uma ordem por OS, com as suas tarefas, o mecânico que assumiu cada uma e os tempos. É um acesso por chave (a OS) e quase sempre da ordem inteira, que é exatamente o que o DynamoDB faz bem, sem esquema fixo para as tarefas.

- **Um item por OS, com as tarefas aninhadas:** uma OS tem poucas tarefas, então o item fica muito abaixo do limite de 400 KB, e ler ou gravar a ordem inteira é uma operação só.
- **Lock otimista no próprio item:** o serviço grava um atributo de versão em cada escrita, então dois mecânicos concluindo tarefas da mesma OS ao mesmo tempo não sobrescrevem um ao outro.
- **Sob demanda, sem capacidade para dimensionar:** nada é cobrado enquanto a tabela está parada, o que combina com o tráfego pequeno e irregular de uma oficina e com um Lab que fica a maior parte do tempo desligado.

## Decisões de desenho

- **Só a chave é declarada.** O DynamoDB não tem esquema para os demais atributos; quem define o formato do item (status, tarefas, `sagaId`, `version`) é o serviço. A chave precisa bater com o que o serviço espera (`serviceOrderId`, string), senão toda leitura e escrita falharia. Foi verificado, veja "Como foi validado".
- **O nome da tabela é o que o serviço lê** em `DYNAMODB_TABLE`, definido no ConfigMap do serviço com o mesmo valor padrão (`execution-orders`). A variável `table_name` só deve mudar junto com o serviço.
- **Sem proteção contra exclusão** (`deletion_protection_enabled = false`): o `destroy` precisa conseguir remover a tabela no fim de cada sessão do Lab. Os dados são de demonstração.
- **Sem secret e sem rede:** a tabela não tem senha e não fica dentro da VPC. Por isso este repositório **não** envia nada para o repositório do serviço e não depende do cluster para ser aplicado.
- **Acesso dos pods pelo role do nó:** o serviço usa as credenciais do role IAM do nó (`LabEksNodeRole`), que o Learner Lab não deixa alterar. Se esse role não permitir `dynamodb:GetItem`, `UpdateItem` e `Scan` nessa tabela, o plano alternativo é fornecer as credenciais da sessão aos pods por um Secret. Isso é verificado na validação no Lab.
- **A tabela é criada por este repositório, não pelo serviço.** O serviço só a cria sozinho quando `DYNAMODB_AUTO_CREATE_TABLE=true` (ambiente local e testes); na AWS essa variável fica desligada.

## Tecnologias

| Camada | Tecnologia |
|---|---|
| Provisionamento | Terraform >= 1.5, provider `hashicorp/aws` |
| Nuvem | AWS (conta acadêmica AWS Academy Learner Lab) |
| Banco | Amazon DynamoDB (sob demanda) |
| CI/CD | GitHub Actions |

## Pré-requisitos

- Terraform >= 1.5
- Conta AWS Academy Learner Lab **ativa**, com credenciais temporárias exportadas

Ao contrário dos repositórios de RDS, **não** é preciso que o `os-infrastructure` tenha sido aplicado antes, nem há token a configurar.

## Executando

O fluxo real é pelo workflow `terraform-apply.yml` (`workflow_dispatch`), porque o state é local ao runner.

```bash
# apenas para inspecionar o plano localmente, com as credenciais do Lab exportadas
terraform init
terraform plan
```

Ordem de uso numa sessão do Lab:

- **Subir:** `os-infrastructure` → `execution-infrastructure` → **este repositório** → deploy do `execution-service`.
- **Desligar:** `destroy` do `execution-service` → **este repositório** → `execution-infrastructure` → `os-infrastructure`.

## CI/CD

- **`terraform-validate.yml`** — em todo push/PR para `develop`/`main`: `terraform fmt -check`, `terraform init -backend=false`, `terraform validate`. Não precisa de credenciais AWS.
- **`terraform-apply.yml`** — disparo manual (`workflow_dispatch`) com escolha entre `plan`, `apply` e `destroy`. Usa as credenciais temporárias do Lab (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, renovadas a cada sessão). Fica manual de propósito, para não gastar o orçamento do Lab a cada merge.

## Variáveis Terraform

Todas têm valor padrão (ver [`variables.tf`](variables.tf)):

| Variável | Padrão | Descrição |
|---|---|---|
| `aws_region` | `us-east-1` | Região (o Learner Lab costuma restringir a `us-east-1`) |
| `table_name` | `execution-orders` | Nome da tabela; é o `DYNAMODB_TABLE` do serviço |

## Como foi validado

- `terraform fmt`, `init`, `validate` e `actionlint` passam (como no `terraform-validate.yml`).
- A tabela foi criada por este Terraform num LocalStack **antes** de qualquer serviço subir, e então o **sistema inteiro rodou com o serviço real** (`os-service/e2e/run-e2e.sh`): fluxo feliz, pagamento recusado e estoque insuficiente, com as filas de erro vazias. O serviço não recriou a tabela (nenhuma linha de criação no log), a usou como está: chave `serviceOrderId` (HASH), cobrança `PAY_PER_REQUEST`, e a ordem do fluxo feliz ficou gravada nela.

**Não validado:** o `apply` contra a AWS real e as permissões dos pods sobre a tabela, que dependem das credenciais e do role do Lab. Isso é verificado na validação no Lab.

## APIs

Este repositório não expõe API própria — é infraestrutura de banco de dados. A API do serviço está no [execution-service](https://github.com/Adriana-Meyer/fiap-tech-challenge-execution-service).
