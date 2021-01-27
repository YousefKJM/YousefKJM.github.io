---
title: "Azure DevOps with ASP .NET Core Web apps"
excerpt: "In this article I would like to present how to use Azure DevOps to provide continuous integration and delivery for ASP .NET Core Web Apps."
header:
  image: /images/posts/article2/adevops1.png
---

<p align="center">
<img src="/images/posts/article2/adevops1.png?raw=true" alt="Microsoft Azure DevOps for ASP .NET Core Web apps"/>
</p>

<!-- > **_P.S.:_**  I cleaned up resources, so some likes would not . -->

<h3><strong>Short introduction</strong></h3>
Before we start with Microsoft Azure DevOps service lets explain what DevOps is. "DevOps is the union of people, process, and products to enable continuous delivery of value to your end users." As you can see this is not one specific thing. Azure DevOps is a solution created to support this "union". It provides tools to manage team work collected in the backlog, it provides GIT repositories to store the code, it provides automatic builds and releases once there is new feature commited. In this article I would like to present how to use Azure DevOps to provide continuous integration and delivery for ASP .NET Core Web Apps. If you want to read more about Azure DevOps visit <a href="https://azure.com/devops" target="_blank" rel="noopener">official website</a>.

&nbsp;
<h3><strong>Project structure and setup</strong></h3>
Creating account in the Azure DevOps is free. You can create one using <a href="https://azure.microsoft.com/en-us/services/devops/?nav=min" target="_blank" rel="noopener">this</a> link. Once you sign in you should see main panel where you can manage your organization settings and projects. Lets start from creating new project. Click "Create project" button. Provide the name for the project and short description. Below select GIT version control and Agile work items process. Click "Create project" button:

<img class=" wp-image-1581 aligncenter" src="/images/posts/article2/adevops2.png?w=238" width="433"  alt="" />

Once project is created you should see navigation panel:

<img class=" wp-image-1583 aligncenter" src="/images/posts/article2/adevops3.png?w=300" alt="" width="767" />

&nbsp;
<h3><strong>Repository setup</strong></h3>
<h3><img class="alignnone wp-image-1601" src="/images/posts/article2/adevops4.png?w=300" alt="" width="156" height="124" /></h3>
In this section we will commit project's code to the GIT repository in the Azure DevOps. For this article I used already created, open source project called "eShopOnWeb". Download its code from <a href="https://github.com/dotnet-architecture/eShopOnWeb" target="_blank" rel="noopener">GitHub here</a>.

<img class=" wp-image-1586 aligncenter" src="/images/posts/article2/adevops5.png?w=234" alt="" width="285" height="364" />

Open "Repos" tab and select "Branches". In the right top corner click "New branch" button. Create two more branches so in total there will be three of them: master, stage and dev:

<img class=" wp-image-1588 aligncenter" src="/images/posts/article2/adevops6.png?w=270" alt="" width="331" />

<img class=" wp-image-1589 aligncenter" src="/images/posts/article2/adevops7.png?w=300" alt="" width="348" />

Once you have branches ready there is one more thing to do - set "dev" branch as default one. Click "Project setting" on the bottom and go to the "Repositories" tab. Click on the "dev" branch and select three dots on the right - select "Set as default branch". Once we have branches ready it is time to commit the code to the "dev" branch. Download code from GitHub first. Then it is time to map our GIT repository. Open "Repos" tab and click "Clone" button. Generate GIT credentials here. I am not sue which tool you prefer to use so lets omit the part with commits, and for me I prefer dealing with git command line since it's a way faster than the other method - the only thing here is that source code from GitHub should be committed to the Azure DevOps GIT repository.

<img class=" wp-image-1595 aligncenter" src="/images/posts/article2/adevops8.png?w=300" alt="" width="351" />

Once you commit the code it should appear in the AzureDevOps portal:

<img class=" wp-image-1614 aligncenter" src="/images/posts/article2/adevops9.png?w=300" alt="" width="515" />

There is great feature for branches called "Branch policy". We can set few different policies for the branch - for instance you cannot complete pull request if you did not set tasks related with it or you cannot complete pull request if the code from your branch cannot be built. Below I presented how to setup policy for "dev" branch. In the "Branches" section click three dots next to "dev" branch and select "Branch policies":

<img class=" wp-image-1723 aligncenter" src="/images/posts/article2/adevops10.png?w=300" alt="" width="453" />

Select "Require a minimum number of reviewers". If you enable this policy you will not be able to merge changes before two specified reviewers will do the code review of your proposed changes:

<img class=" wp-image-1724 aligncenter" src="/images/posts/article2/adevops11.png?w=300" alt="" width="575" />

This will also enforce the use of pull requests when updating the branch.

&nbsp;
<h3><strong>Board setup</strong></h3>
<h3><img class="alignnone wp-image-1603" src="/images/posts/article2/adevops12.png?w=300" alt="" width="168" height="121" /></h3>
With Azure DevOps boards you can plan the team work and create backlog for your product. You can create tasks, issues, bugs, user stories and features:

<img class=" wp-image-1607 aligncenter" src="/images/posts/article2/adevops13.png?w=300" alt="" width="615" />

If you want to read more about backlog configuration with Azure DevOps please refer to <a href="https://docs.microsoft.com/en-us/azure/devops/boards/backlogs/backlogs-overview?view=vsts&amp;tabs=new-nav" target="_blank" rel="noopener">this</a> documentation.

For now we will create one user story and one task inside it. User story and task will be related with updating ReadMe file:

<img class=" wp-image-1609 aligncenter" src="/images/posts/article2/adevops14.png?w=300" alt="" width="745" />

Of course you can add as many stories as you need for the project.

&nbsp;
<h3><strong>Build pipeline setup</strong></h3>
<h3><img class="alignnone wp-image-1604" src="/images/posts/article2/adevops15.png?w=300" alt="" width="175" height="122" /></h3>
In this section we will setup build pipeline for our web app project. We want to build the code each time when there is an update on the source code from "dev" branch. To configure automatic build open "Pipelines" tab and open "Pipelines" section:

<img class=" wp-image-1618 aligncenter" src="/images/posts/article2/adevops16.png?w=300" alt="" width="345" />

Click "Create pipeline" button and then select "Use the classic editor to create a pipeline without YAML."

There are few steps:

1. Location-we have to indicate where the code is located - in our case this will be "Azure Repos GIT": <br> 
  <img class=" wp-image-1630 aligncenter" src="/images/posts/article2/adevops17.png?w=300" alt="" width="457" />

2. In this step we can select template for our build - this is very convenient because we do not have to define everything from scratch. Select "ASP .NET Core" template: <br> 
  <img class=" wp-image-1631 aligncenter" src="/images/posts/article2/adevops18.png?w=300" alt="" width="641" />

3. There will be pre-configured steps displayed. We want to build our code each time new merge is done. To do this select "Enable continuous integration" in the "Triggers" section: <br>
  <img class=" wp-image-1633 aligncenter" src="/images/posts/article2/adevops19.png?w=300" alt="" width="528" />
  <img class=" wp-image-1634 aligncenter" src="/images/posts/article2/adevops20.png?w=300" alt="" width="643" />

4. Lets change build definition name to "eShopOnAzureDevOps-ASP.NET Core-CI-DEV"-just click on the text on top.

5. Click "Save &amp; queue" button. Select "Azure Pipelines" as build agent. New build should be scheduled: <br>
  <img class=" wp-image-1638 aligncenter" src="/images/posts/article2/adevops21.png?w=300" alt="" width="389"  />
  <img class=" wp-image-1637 aligncenter" src="/images/posts/article2/adevops22.png?w=300" alt="" width="643" />

6. Once build if finished we can check the result: <br>
  <img class=" wp-image-1641 aligncenter" src="/images/posts/article2/adevops23.png?w=300" alt="" width="529" />

We can move forward to the next section.

&nbsp;
<h3><strong>Release pipeline setup</strong></h3>
<img class="alignnone wp-image-1604" src="/images/posts/article2/adevops24.png?w=300" alt="" width="171" height="119" />


> **_NOTE:_**  <span style="color:red"> I scaled down Azure service plan to the free tier to stop billing so all deployment slots has been removed and I may do clean all resources after a while so some links below will not work properly.</span>


We will host our application using Microsoft Azure Web App service. In this section I would like to present how to use Azure Web App deployment slots so you can deploy two (or more) versions of the application so its available under different URL addresses. You can read more about deployment slots <a href="https://docs.microsoft.com/en-us/azure/app-service/web-sites-staged-publishing" target="_blank" rel="noopener">here</a>. As a result of below setup we will configure two different release pipelines: one for demo and one for production.

<strong>Create web application in Azure portal</strong>

Login to the Azure portal and create new Web App service inside new resource group:

<img class=" wp-image-1647 aligncenter" src="/images/posts/article2/adevops25.png?w=145" alt="" width="300" />

Please remember to select S1 App Service Plan because it provides deployment slots feature. Once Web App is created open it and go to the "Deployment slots" tab:

<img class=" wp-image-1649 aligncenter" src="/images/posts/article2/adevops26.png?w=300" alt="" width="704" />

Click "Add Slot" button and add new slot called "demo". Copy configuration from production slot:

<img class=" wp-image-1651 aligncenter" src="/images/posts/article2/adevops27.png?w=210" alt="" width="399" />

Once deployment slot is created click it. Note that there is new URL created:

https://eshoponazuredevops-<strong>demo</strong>.azurewebsites.net

Production app URL looks like below:

https://eshoponazuredevops.azurewebsites.net

Now we can connect Azure DevOps with Azure subscription to configure release pipeline.

&nbsp;

<strong>Setup connection between Azure and Azure DevOps</strong>

Click "Project settings" on the bottom of AzureDevOps page. Go to "Service connections" under "Pipeline" section. Click "Create service connection" and select "Azure Resource Manager" and then select "Service principal (automatic)":

<img class=" wp-image-1655 aligncenter" src="/images/posts/article2/adevops28.png?w=262" alt="" width="410" />

Select Azure subscription, resource group and type connection name. Then click "Save":

<img class=" wp-image-1658 aligncenter" src="/images/posts/article2/adevops29.png?w=300" alt="" width="496" />

Connection should be visible on the list. Now we can configure release pipeline.

&nbsp;

<strong>Configure release pipeline</strong>

Open "Releases" tab in the "Pipelines" section:

<img class=" wp-image-1661 aligncenter" src="/images/posts/article2/adevops30.png?w=300" alt="" width="374" />

Click "New pipeline" button. On the right side please find and select "Azure App Service deployment with slot":

<img class=" wp-image-1664 aligncenter" src="/images/posts/article2/adevops31.png?w=300" alt="" width="612" />

Type "Demo" in the "stage name" field and click "X" icon to close the tab:

<img class=" wp-image-1667 aligncenter" src="/images/posts/article2/adevops32.png?w=300" alt="" width="531" />

Now change the name of the release to: "Demo release pipeline" and after that click "Add an artifact":

<img class=" wp-image-1671 aligncenter" src="/images/posts/article2/adevops33.png?w=300" alt="" width="520" />

Select project and then set "default version" to "latest". "Source alias" should be set to "_eShopOnAzureDevOps-ASP.NET Core-CI-DEV" - our build definition we created earlier in the article:

<img class=" wp-image-1673 aligncenter" src="/images/posts/article2/adevops34.png?w=285" alt="" width="494" />

Once you click "Add" button you should see configured artifact for our release pipeline definition:

<img class=" wp-image-1677 aligncenter" src="/images/posts/article2/adevops35.png?w=300" alt="" width="459" />

&nbsp;

Now we have to integrate our release pipeline with the Azure Web App created earlier in the article. Click "1 job, 2 tasks" under "Demo"stage. In this step you have to provide name of the Azure subscription, App type, Azure service name, Resource group and Slot (in this case "demo"):

<img class=" wp-image-1679 aligncenter" src="/images/posts/article2/adevops36.png?w=300" alt="" width="836" />

For now we can remove next step called "Slot swap". Click remove in the right top corner to remove this step from the release pipeline. Only deploy to slot should remain:

<img class=" wp-image-1683 aligncenter" src="/images/posts/article2/adevops37.png?w=300" alt="" width="485" />

Click "Save" and then "OK" buttons. Our final pipeline looks like presented below:

<img class=" wp-image-1687 aligncenter" src="/images/posts/article2/adevops38.png?w=300" alt="" width="491" />

One more thing - we need to enable trigger for this release pipeline each time there is new build. Click lightning icon in the "Artifacts" and enable below trigger. Then click "Save" and "OK" buttons:

<img class="alignnone wp-image-1691 aligncenter" src="/images/posts/article2/adevops39.png?w=300" alt="" width="474" />

&nbsp;

&nbsp;

<strong>Test release pipeline for demo slot</strong>

Now we can try to test whether we configure everything properly. Try to commit some changes to the dev branch and see if build was scheduled and if release was completed successfully. If everything went ok you should access web app under demo URL address:

[https://eshoponazuredevops-demo.azurewebsites.net](https://eshoponazuredevops-demo.azurewebsites.net){:target="_blank"}

<img class=" wp-image-1693 aligncenter" src="/images/posts/article2/adevops40.png?w=300" alt="" width="570" />

Please note that under production URL https://eshoponazuredevops.azurewebsites.net there is no app available:

<img class=" wp-image-1696 aligncenter" src="/images/posts/article2/adevops41.png?w=300" alt="" width="575" />

&nbsp;

<strong>Configure slot swap in the release definition</strong>

Once demo environment is ready we can use "slot swap". This step in release pipeline enables moving application from the "demo" slot to the production slot.

Click "Add" button under "Demo" stage:

<img class=" wp-image-1700 aligncenter" src="/images/posts/article2/adevops42.png?w=300" alt="" width="580" />

Again search for "Azure App Service deployment with slot" template and type "Production" as stage name. Click "X" button in the right corner. Now our pipeline look like below:

<img class=" wp-image-1703 aligncenter" src="/images/posts/article2/adevops43.png?w=300" alt="" width="553" />

Now click "1 job, 2 tasks" on the Production stage. This time remove "Deploy Azure App Service to Slot" and in the "Manage Azure App Service - Slot Swap". Again select Azure subscription, app service name, resource group and slot:

<img class=" wp-image-1706 aligncenter" src="/images/posts/article2/adevops44.png?w=300" alt="" width="539" />

Click "Save" and then "OK" button. Now we want to have approval before demo app is moved to production. It means that someone has to confirm this slot swap. We have to set pre-deployment conditions. Click lightning icon on the Production stage and then set "Pre-deployment approvals" to enabled:

<img class=" wp-image-1709 aligncenter" src="/images/posts/article2/adevops45.png?w=300" alt="" width="645" />

Then set one of the approvers - person (or people) who will accept deployment to Production stage:

<img class=" wp-image-1711 aligncenter" src="/images/posts/article2/adevops46.png?w=300" alt="" width="618" />

Click "Save" and then "OK" button. Now try to commit some changes to the source code of the web app. Before there is slot swap to Production you will have to wait for approval. Approves should receive e-mails with the information that new build is ready and swap to Production can be proceeded:

<img class=" wp-image-1717 aligncenter" src="/images/posts/article2/adevops47.png?w=300" alt="" width="595" />
<img class=" wp-image-1718 aligncenter" src="/images/posts/article2/adevops48.png?w=300" alt="" width="600" />


Once swap is approved in the portal information about deployment is displayed:

<img class=" wp-image-1718 aligncenter" src="/images/posts/article2/adevops49.png?w=300" alt="" width="600" />

Now lets try to open production URL: [https://eshoponazuredevops.azurewebsites.net](https://eshoponazuredevops.azurewebsites.net){:target="_blank"}

<img class=" wp-image-1720 aligncenter" src="/images/posts/article2/adevops50.png?w=300" alt="" width="608" />

&nbsp;
<h3><strong>Summary</strong></h3>
Microsoft Azure DevOps provides tools to manage team work collected in the backlog, it provides GIT repositories to store the code, it provides automatic builds and releases. It help developers and DevOps engineers with setting up the whole Development and Operations related stuff. It is available for free and its worth to mention that it supports not only Microsoft technologies (like ASP .NET Core web applications mentioned in this article). You can read more about Azure DevOps on the official <a href="https://azure.microsoft.com/en-us/services/devops/" target="_blank" rel="noopener">website</a>.