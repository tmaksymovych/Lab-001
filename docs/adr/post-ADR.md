## 1. Чому з'явився цей файл (Зіткнення плану з реальністю пісочниці)

У першому `ADR.md` я спланував ідеальну архітектуру до запуску коду (зокрема хотів деплоїти все у Стокгольмі `eu-north-1`). Але коли ми почали реально піднімати інфраструктуру через AWS CLI та Terraform у пісочниці (`Account ID: 381491842844`), вилізли жорсткі обмеження самої AWS Academy. Ось що довелося змінити на льоту і які помилки ми зловили.

---

## 2. Вимушена зміна регіону: `eu-north-1` -> `us-east-1`

При першій же спробі перевірити VPC у Стокгольмі (`eu-north-1`) AWS повернув помилку:
```text
An error occurred (UnauthorizedOperation) when calling the DescribeVpcs operation:
User: arn:aws:sts::381491842844:assumed-role/voclabs/user5477809=tmaksymovych@kse.org.ua
is not authorized to perform: ec2:DescribeVpcs with an explicit deny in a service control policy:
arn:aws:organizations::851725210750:policy/o-vqqsni5hk2/service_control_policy/p-ktyy86af
```

**Що це значить:** На рівні AWS Organizations над нашим акаунтом висить глобальна політика SCP (`p-ktyy86af`), яка ставить `explicit deny` на всі європейські регіони. Ми просканували регіони скриптом і з'ясували, що відкриті лише два американські: **`us-east-1` (N. Virginia)** та **`us-west-2` (Oregon)**.

# Рішення:
Переїхали в **`us-east-1`** (зони `us-east-1a` та `us-east-1b`). Сама CIDR-схема (`10.0.0.0/16` і 4 підмережі `/24`: `1, 2` та `11, 12`) залишилась без змін, просто перемкнули змінну регіону в Terraform.

---

## 3. Перерахунок цін (FinOps під `us-east-1`)(ші розрахунки)

Оскільки регіон змінився зі Стокгольма на Вірджинію (`us-east-1`), трохи змінилися і тарифи на майбутній Milestone 2 (1 Coordinator + 2 Shards на `t3.micro`, якщо крутити 24/7 всі 730 годин):

- **Інстанси `t3.micro`**: у Вірджинії трохи дорожчі — **$0.0104/год** замість $0.0098/год (за 3 ноди виходить **$22.78/міс** замість $21.45/міс).
- **Диски EBS `gp3` (30 GB)**: у Вірджинії дешевші — **$0.08/GB** замість $0.088/GB (**$2.40/міс** замість $2.64/міс).
- **Публічна IPv4 (для Coordinator)**: **$0.005/год** (**$3.65/міс**).
- **Трафік між зонами**: ~$0.15/міс.
- **Нова сума 24/7**: **~$28.98/міс** (проти $27.89 у Стокгольмі). У ліміт пісочниці ($50–$100) все одно легко влізаємо, особливо якщо гасити інстанси між лабами.
- **NAT Gateway**: у `us-east-1` коштує $0.045/год (~$32.85/міс за один або ~$65.70/міс за два), тому наша відмова від NAT Gateway (Zero NAT) актуальна так само на 100%.

---

## 4. Розтин `LabRole` (насправді `voclabs`) та всі IAM-помилки, які ми зловили

Перший прикол: при спробі подивитися роль `LabRole` ми зловили:
```text
An error occurred (NoSuchEntity) when calling the GetRole operation: The role with name LabRole cannot be found.
```
Через `aws sts get-caller-identity` та `aws iam list-roles` ми вияснили, що в нашому Sandbox основна роль називається не `LabRole`, а **`voclabs`** (плюс у акаунті є готові сервісні ролі `myS3Role`, `lambda-run-role`, `myBasicLambdaRole`, `EMR_EC2_DefaultRole`).

У ролі `voclabs` прикріплені дві політики:
1. Managed-політика **`ReadOnlyAccess`** (дає право читати майже все, навіть список ролей в IAM).
2. Inline-політика **`Pvoclabs`** (дає основні права на створення ресурсів).

### Помилка при спробі прочитати саму `Pvoclabs`:
Коли ми спробували витягнути JSON-текст політики `Pvoclabs` командою `aws iam get-role-policy --role-name voclabs --policy-name Pvoclabs`, зловили таке:
```text
An error occurred (AccessDenied) when calling the GetRolePolicy operation:
User: arn:aws:sts::381491842844:assumed-role/voclabs/user5477809=tmaksymovych@kse.org.ua
is not authorized to perform: iam:GetRolePolicy on resource: role voclabs
with an explicit deny in an identity-based policy.
```
Тобто автори пісочниці спеціально вшили **Explicit Deny на `iam:GetRolePolicy`** прямо всередину `Pvoclabs`, щоб студенти не могли скачати текст політики напряму!

Тому ми(я і аргон) обійшли це легально через офіційний **IAM Policy Simulator** (`aws iam simulate-principal-policy --policy-source-arn arn:aws:iam::381491842844:role/voclabs ...`) і отримали точний розклад:
- **Дозволено (`allowed`)**: `ec2:RunInstances`, `ec2:CreateVpc`, `ec2:CreateSubnet`, `s3:CreateBucket`, `dynamodb:CreateTable`, `lambda:CreateFunction`, `rds:CreateDBInstance`.
- **Неявно заборонено (`implicitDeny` — просто нема прав у `Pvoclabs`)**: `iam:CreateRole`, `iam:CreatePolicy`, `iam:CreateUser`, `iam:AttachRolePolicy`, `iam:PassRole`, `eks:CreateCluster`.
- **Явно заблоковано (`explicitDeny`)**: `organizations:DescribeOrganization`, `route53domains:RegisterDomain` + всі регіони крім `us-east-1` та `us-west-2`.

### Помилки при спробі задеплоїти наш `infra/iam-spec` (Завдання 2 і 3):
Аргон на здивування виявився правий і в `ADR.md` (чому розділили стеки на `network` і `iam-spec`), при запуску `terraform apply` у папці `infra/iam-spec` AWS відбив обидва ресурси з помилкою `403 AccessDenied`:

1. **На створення Read-Only Policy (`LightDynamoDBReadOnlyPolicy`):**
```text
Error: creating IAM Policy (LightDynamoDBReadOnlyPolicy): operation error IAM: CreatePolicy,
https response error StatusCode: 403, api error AccessDenied:
User: arn:aws:sts::381491842844:assumed-role/voclabs/user5477809=tmaksymovych@kse.org.ua
is not authorized to perform: iam:CreatePolicy on resource: policy LightDynamoDBReadOnlyPolicy
because no identity-based policy allows the iam:CreatePolicy action.
```

2. **На створення Assumable Role (`LightDynamoDBReadOnlyRole`):**
```text
Error: creating IAM Role (LightDynamoDBReadOnlyRole): operation error IAM: CreateRole,
https response error StatusCode: 403, api error AccessDenied:
User: arn:aws:sts::381491842844:assumed-role/voclabs/user5477809=tmaksymovych@kse.org.ua
is not authorized to perform: iam:CreateRole on resource: arn:aws:iam::381491842844:role/LightDynamoDBReadOnlyRole
because no identity-based policy allows the iam:CreateRole action.
```
Це на 100% підтвердило правильність нашого рішення про **Stack Layout**: якби ці IAM-ресурси лежали в одному стеку з мережею, ми б не змогли нормально працювати зі стеком мережі.

---

## 5. Результат тесту на відтворюваність (Teardown & Recreate)

Мережевий стек (`infra/network` — 13 ресурсів) у `us-east-1` піднявся і перестворився без жодної помилки:
- Повне видалення (`terraform destroy`): **13 секунд**.
- Повне створення з нуля (`terraform apply`): **35 секунд**.
- Загальний час циклу: **48 секунд**.
