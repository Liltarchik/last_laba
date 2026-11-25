# ЛР7–8 Terraform і GitHub Actions на AWS

У цьому прогоні Terraform створює інфраструктуру в Frankfurt. GitHub Actions тестує контейнер Flask, публікує його в Amazon ECR, запускає Amazon EC2 і перевіряє вебзастосунок через HTTP. Для обох частин використовується один інстанс EC2. Стан розгортання зберігається у версійованому приватному бакеті S3. Terraform блокує паралельні зміни через файл `.tflock`. [Terraform S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3)

## Автоматичний запуск на Mac

У робочій копії в `university` виконай `./aws-lab78.sh --public`. Скрипт використовує наявний репозиторій `Liltarchik/last_laba` і додає AWS-файли в `aws-lab78/`, а workflow — у `.github/workflows/lab78-aws.yml`. Підтверди вхід AWS та GitHub у браузері. Скрипт покаже статус AWS Free Tier, якщо акаунт дає його прочитати, та Terraform plan. Після перевірки плану введи `yes`, щоб створити ресурси й запустити workflow.

AWS CLI використовує тимчасові облікові дані. Локальні AWS-налаштування зберігаються у приватній `.aws/` цієї теки. GitHub Actions отримує окрему IAM Role через OIDC. Її довіра обмежена `Liltarchik/last_laba` і гілкою `main`. [AWS CLI login](https://docs.aws.amazon.com/cli/latest/reference/login/)

## Що показати для захисту

- **ЛР7.** У workflow відкрий `terraform plan` та `terraform apply`. У консолі покажи `lab78-flask` (EC2), security group з HTTP та приватний S3 бакет із ключем `lab78/terraform.tfstate`.
- **ЛР8.** Покажи тег коміту та digest у ECR, успішні результати тестів `200` і `404`, URL застосунку у GitHub Actions Summary. Поясни, як EC2 читає образ через instance role, а GitHub отримує тимчасовий доступ через OIDC.
- У методичці контейнер також демонструють на Lightsail. Цей варіант запускає власний Flask-контейнер на EC2. Для блокування S3 state використано сучасний `use_lockfile`.

## Завершення

Збережи скриншоти й журнал workflow до завершення Free Trial. Після демонстрації видали інстанс через Terraform із робочого каталогу deploy і тим самим backend. Далі очисть лише лабораторні ECR-образи та всі версії об’єктів у лабораторному S3 bucket перед видаленням bootstrap. Зовнішній OIDC provider, використаний повторно, до bootstrap state не додається. Перевір, що видалив саме ресурси цієї лабораторної.
