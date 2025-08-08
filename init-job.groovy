import jenkins.model.*
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition
import hudson.plugins.git.GitSCM
import hudson.plugins.git.extensions.impl.*

def instance = Jenkins.getInstance()

if (instance.getItem("MyPipeline") == null) {
    def job = new WorkflowJob(instance, "MyPipeline")
    def scm = new GitSCM("https://github.com/FrothyRythm/project010.git")
    scm.getExtensions().add(new RelativeTargetDirectory("."))
    job.setDefinition(new CpsScmFlowDefinition(scm, "Jenkinsfile"))
    instance.add(job, "MyPipeline")
    job.save()
}

instance.save()
