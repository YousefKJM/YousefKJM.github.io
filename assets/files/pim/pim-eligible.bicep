targetScope = 'subscription'

@description('Object ID of the Entra group that becomes eligible (PIM for Groups recommended)')
param principalId string

@description('Built-in role to make eligible - default: Contributor')
param roleDefinitionGuid string = 'b24988ac-6181-4d38-a0d7-8a2c4aeb6a31'

param startDateTime string = utcNow()

resource eligible 'Microsoft.Authorization/roleEligibilityScheduleRequests@2022-04-01-preview' = {
  name: guid(subscription().id, principalId, roleDefinitionGuid)
  properties: {
    principalId: principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionGuid)
    requestType: 'AdminAssign'
    justification: 'Eligible Contributor for the platform team - managed in Git'
    scheduleInfo: {
      startDateTime: startDateTime
      expiration: {
        type: 'AfterDuration'
        duration: 'P180D'          // eligibility itself expires: forces a re-review every 6 months
      }
    }
  }
}
