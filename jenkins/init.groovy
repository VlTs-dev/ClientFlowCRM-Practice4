import jenkins.model.Jenkins
import jenkins.model.JenkinsLocationConfiguration
import hudson.security.HudsonPrivateSecurityRealm
import hudson.security.FullControlOnceLoggedInAuthorizationStrategy
import hudson.plugins.git.GitSCM
import hudson.plugins.git.GitTool
import hudson.plugins.git.UserRemoteConfig
import hudson.plugins.git.BranchSpec
import org.jenkinsci.plugins.gitclient.JGitTool
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition
import com.cloudbees.plugins.credentials.CredentialsScope
import com.cloudbees.plugins.credentials.SystemCredentialsProvider
import org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl
import hudson.util.Secret

def j = Jenkins.get()
def password = System.getenv('CRM_ADMIN_PASSWORD')
if (password) {
    def realm = new HudsonPrivateSecurityRealm(false)
    realm.createAccount('student', password)
    j.setSecurityRealm(realm)
    def authorization = new FullControlOnceLoggedInAuthorizationStrategy()
    authorization.setAllowAnonymousRead(false)
    j.setAuthorizationStrategy(authorization)
}
j.setNumExecutors(1)
j.setSystemMessage('Практическая работа 4 · ClientFlowCRM · Цибулин В В · ИКБО-22-23')
JenkinsLocationConfiguration.get().setUrl(System.getenv('CRM_JENKINS_URL'))
def gitPath = System.getenv('CRM_GIT_EXE')
if (gitPath) {
    j.getDescriptorByType(GitTool.DescriptorImpl).setInstallations(
        [new JGitTool([]), new GitTool('Default', gitPath, [])] as GitTool[])
}
def credentials = SystemCredentialsProvider.getInstance().getCredentials()
if (!credentials.find { it.id == 'clientflowcrm-demo-token' }) {
    credentials.add(new StringCredentialsImpl(CredentialsScope.GLOBAL,
        'clientflowcrm-demo-token', 'Учебный токен без доступа к внешним системам',
        Secret.fromString('clientflowcrm-training-value')))
    SystemCredentialsProvider.getInstance().save()
}
def job = j.getItem('ClientFlowCRM-CICD')
if (!job) {
    job = j.createProject(WorkflowJob.class, 'ClientFlowCRM-CICD')
}
job.setDescription('Учебный CI/CD для ClientFlowCRM: сборка пакета, проверки, staging, подтверждение и production')
def scm = new GitSCM(
    [new UserRemoteConfig(System.getenv('CRM_REPOSITORY_URL'), null, null, null)],
    [new BranchSpec('*/main')], false, [], null, 'jgit', [])
def definition = new CpsScmFlowDefinition(scm, 'Jenkinsfile')
definition.setLightweight(true)
job.setDefinition(definition)
job.save()
j.save()
println 'ClientFlowCRM: secure local Jenkins and pipeline configured'
