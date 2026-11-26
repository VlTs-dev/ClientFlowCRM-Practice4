def runBash(String command) {
    if (isUnix()) {
        sh "bash ${command}"
    } else {
        def parts = command.tokenize(' ')
        def windowsScript = parts[0].replace('.sh', '.ps1')
        if (!windowsScript.startsWith('scripts/')) {
            windowsScript = "scripts/${windowsScript}.ps1"
        }
        def arguments = parts.size() > 1 ? " -Target ${parts[1]}" : ''
        bat "@powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File ${windowsScript}${arguments}"
    }
}

pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    parameters {
        booleanParam(name: 'SIMULATE_FAILURE', defaultValue: false,
            description: 'Учебная проверка обработки ошибки на этапе тестирования')
        booleanParam(name: 'SEND_EMAIL', defaultValue: false,
            description: 'Отправлять уведомления об ошибках после настройки SMTP')
        string(name: 'NOTIFY_EMAIL', defaultValue: '',
            description: 'Адрес для уведомлений при включённом SEND_EMAIL')
    }

    environment {
        PROJECT_NAME = 'ClientFlowCRM'
        CRM_DEMO_TOKEN = credentials('clientflowcrm-demo-token')
    }

    stages {
        stage('Сборка') {
            steps {
                echo "Проект ${env.PROJECT_NAME}, сборка ${env.BUILD_NUMBER}"
                runBash('scripts/build.sh')
            }
        }
        stage('Тестирование') {
            steps {
                runBash('scripts/test.sh')
                script {
                    if (params.SIMULATE_FAILURE) {
                        error('Учебная ошибка: проверка обработки неудачного запуска')
                    }
                }
            }
        }
        stage('Стейджинг') {
            steps {
                runBash('deploy staging')
            }
        }
        stage('Проверка стейджинга') {
            steps {
                runBash('smoke-tests staging')
            }
        }
        stage('Подтверждение') {
            steps {
                timeout(time: 30, unit: 'MINUTES') {
                    input id: 'ReleaseToProduction',
                        message: 'Выпустить учебный пакет ClientFlowCRM в production?',
                        ok: 'Выпустить'
                }
            }
        }
        stage('Продакшн') {
            steps {
                runBash('deploy production')
                runBash('smoke-tests production')
            }
        }
    }

    post {
        always {
            echo "Завершён запуск ${env.JOB_NAME} #${env.BUILD_NUMBER}"
            archiveArtifacts artifacts: 'dist/**,environments/**', allowEmptyArchive: true
        }
        success {
            echo 'ClientFlowCRM: все этапы конвейера выполнены успешно'
        }
        failure {
            echo 'ClientFlowCRM: ошибка конвейера, выпуск остановлен'
            script {
                if (params.SEND_EMAIL && params.NOTIFY_EMAIL?.trim()) {
                    mail to: params.NOTIFY_EMAIL.trim(),
                        subject: "ClientFlowCRM: ошибка сборки #${env.BUILD_NUMBER}",
                        body: "Подробности: ${env.BUILD_URL}console"
                } else {
                    echo 'Уведомление зарегистрировано в журнале; отправка email выключена'
                }
            }
        }
        changed {
            echo 'Результат конвейера изменился по сравнению с предыдущим запуском'
        }
        fixed {
            echo 'Работоспособность конвейера восстановлена после ошибки'
        }
        cleanup {
            deleteDir()
        }
    }
}
