public with sharing class ADVClassTool {
    public static Boolean Dom_inside;
	public static Id beforeAccountId;
    public static String beforeAccountName;

    //Test devops (luc)
    public static List<Map<String, Object>> controlAbo(List<OpportunityLineItem> ListItem, Boolean Dom_inside_create, Date Date_activation_contrat) {
		Dom_inside = Dom_inside_create;
        List<Map<String, Object>> produitItems = new List<Map<String, Object>>();

        for (OpportunityLineItem lp_adv : ListItem){
            System.debug('controlAbo lp_adv.Product2Id = ' + lp_adv.Product2Id);
            System.debug('controlAbo lp_adv.OpportunityId = ' + lp_adv.OpportunityId);

            List<Abonnement__c> ListAbonement_adv = [
                SELECT Id, Date_activation__c, Produit__r.Id, Produit__r.Name, Produit__r.Description, Produit__r.UnitPrice__c, Produit__r.ProductCode, Opportunite__r.Id, Remise__c 
                FROM Abonnement__c 
                WHERE (Produit__r.Id = :lp_adv.Product2Id AND  Opportunite__r.Id = :lp_adv.OpportunityId)];
            
            for (Abonnement__c abonnement_adv : ListAbonement_adv) {
                if (abonnement_adv.Produit__r.ProductCode.startsWith('DOM_')) {
                    Dom_inside = abonnement_adv.Produit__r.ProductCode.startsWith('DOM_');
                    if(Date_activation_contrat == null){
                    	Date_activation_contrat = abonnement_adv.Date_activation__c;
                    }
                    System.debug('DOM_ = ' + abonnement_adv.Produit__r.ProductCode);    
                    System.debug('Date_activation_contrat = ' + Date_activation_contrat);
                }

                if (abonnement_adv.Produit__r.Description == null) {
                    abonnement_adv.Produit__r.Description = abonnement_adv.Produit__r.Name;
                }
                
				OpportunityLineItem oppLineItem = [SELECT UnitPrice FROM OpportunityLineItem WHERE 	OpportunityId = :lp_adv.OpportunityId AND Product2Id = :abonnement_adv.Produit__r.Id];
                
                produitItems.add(new Map<String, Object>{
                    'price' => oppLineItem.UnitPrice,
                    'quantity' => 1,
                    'description' => abonnement_adv.Produit__r.Description,
                    'name' => abonnement_adv.Produit__r.Name,
                    'code' => abonnement_adv.Produit__r.ProductCode,
                    'discount' => abonnement_adv.Remise__c
                });
            }
        }
        return produitItems;
    }
    
    //Creation de tache
    public static void createTask(String subject, String Description, Id contactId, Id whatId){
		Task newTask = new Task();
		newTask.subject = subject;
        newTask.Description = Description;
		newTask.whatId = whatId; //account.Id;
		newTask.whoId= contactId;
		newTask.ownerId = '00G690000054tDEEAY'; //account.Collection_Ownership__c;
		newTask.status = 'Not Started';
        newTask.Type = 'Autre';
		newTask.Priority = 'Haute';
        
        insert newTask;
    }
    
    //traitement du message d'erreur format text avec retour chariot
    public static String List2String(List<String> Message) {
        String MessComplet = '';
        for (String Mess : Message) {
			MessComplet += Mess + '\r';
        }
        return MessComplet;
    }
    
    //info de l'opportunité
    public static Opportunity opportunityRecord(Id recordId) {
    	return [SELECT Name, statut_advbot__c,AccountId,AccountName__c,Contact_Principal__c,BU__c,Date_du_paiement__c,remise_cciale_exceptionnelle__c,Lien_procedure_ADV__c,Pricebook2Id,date_debut_contrat__c,nb_produits_domiciliation__c FROM Opportunity WHERE Id = :recordId];
    }

    //Liste des produits de l'opportunité
    public static List<OpportunityLineItem> oppLineItemList(Id recordId) {
        return [SELECT Product2Id,OpportunityId FROM OpportunityLineItem where OpportunityId = :recordId];
	}
    
	// Liste des relations du contact
    public static list<OpportunityContactRole> oppContactList(Id ContactId) {
        return [SELECT ContactId,Role,OpportunityId,Contact.AccountId FROM OpportunityContactRole WHERE ContactId = :ContactId LIMIT 2];
    }

    public static Opportunity OppPending(Id ContactId, Id OppId) {
        Opportunity oppOne = new Opportunity();
        List<Opportunity> oppNext = [SELECT Id,AccountId,ContactId,AccountName__c,Date_du_paiement__c,Name,StageName,nb_produits_domiciliation__c FROM Opportunity WHERE ContactId = :ContactId AND StageName = 'Accord client' AND Date_du_paiement__c != null AND ID NOT IN (:OppId)];
          if(oppNext.size() > 0){
          	oppOne = oppNext[0];
          }
        return oppOne;
    }
    
    //Control pour la procedure unique (pardot)
    public static List<String> controlOpp(List<String> Message, Id recordId, Id ContactId, String ContactFirstName, String ContactLastName, String ContactRole) {
        if (ContactFirstName != 'Service' && ContactLastName != 'Formalités' && ContactRole != 'Mandataire') {
            Opportunity Opportunite = new Opportunity();
            List<String> MessageIn = new List<String>();
            List<OpportunityContactRole> oppContactRoleList = oppContactList(ContactId);
    
            for (OpportunityContactRole OpportunityContact : oppContactRoleList) {
                Opportunite = opportunityRecord(OpportunityContact.OpportunityId);
                if ((recordId != OpportunityContact.OpportunityId) && (Opportunite.statut_advbot__c != null && Opportunite.statut_advbot__c != 'Terminé')){
                    MessageIn.add(Opportunite.Name+ '\r');
                    MessageIn.add('a le status : ' + Opportunite.statut_advbot__c);
                    beforeAccountId = Opportunite.AccountId;
                    BeforeAccountName = Opportunite.AccountName__c;
                }
            }
            if (!MessageIn.isEmpty()) {
                
                Message.add('La procedure ADV ne peut pas être créée.'+ '\r');
                Message.add('Cette Opportunité : '+ '\r');
                Message.addAll(MessageIn);
            }
        }
        return Message;
    }
   
    //relation entre l'opportunité et le contact
    public static List<OpportunityContactRole> oppContactRoleList (Id recordId) {
        List<OpportunityContactRole> oppContactRoleList = new List<OpportunityContactRole>();
        List<OpportunityContactRole> oppContactRoleListSelect = [SELECT ContactId,Role,OpportunityId FROM OpportunityContactRole WHERE OpportunityId = :recordId];
        
        //control du contact present en role-------------------------------------
        if (!oppContactRoleListSelect.isEmpty()) {
            System.debug('if oppContactRoleListSelect ' + oppContactRoleListSelect.size());
            for(Integer i = 0; i < oppContactRoleListSelect.size(); i++){
                if (oppContactRoleListSelect[i].Role == 'Mandataire') {
                    oppContactRoleList.add(oppContactRoleListSelect[i]);
                } else if (oppContactRoleListSelect[i].Role == 'Signataire du contrat') {
                    System.debug('oppContactRoleList : ContactId ' + i +' = '+ oppContactRoleListSelect[i].ContactId);
                    oppContactRoleList.add(oppContactRoleListSelect[i]);
                } else if (oppContactRoleListSelect[i].Role != 'Signataire du contrat' && oppContactRoleListSelect[i].Role == 'Mandataire') {
                    oppContactRoleList.add(oppContactRoleListSelect[i]);
                }
            }
            System.debug('oppContactRoleList = '+ oppContactRoleList);
            return oppContactRoleList; // retourner la liste complète après avoir parcouru tous les éléments
        } else {   
            return oppContactRoleListSelect; // retourner une liste vide si aucun élément n'est trouvé
        }
    }

    //info du compte
    public static Account account(Id AccountId) {
        return [SELECT Name,BillingCity,BillingCountry,BillingPostalCode,BillingStreet,Website,Periode_de_facturation__c,Code_Sage_maj_auto__c,adresse_mail_pour_envoi_de_la_facture__c FROM Account WHERE Id = :AccountId];
    }
    
    //info du contact
    public static List<Contact> contact(Id ContactId) {
        return [SELECT Id,Email,Birthdate,FirstName,LastName,MobilePhone,Phone FROM Contact WHERE Id = :ContactId];
    }
    
    //relation entre compte et contact
    public static AccountContactRelation accountContactRole(Id AccountId, Id ContactId) {
        System.debug('AccountId        = ' + AccountId);
        System.debug('ContactId        = ' + ContactId);
        return [SELECT AccountId,Roles,ContactId,Representant_legal__c FROM AccountContactRelation WHERE AccountId = :AccountId AND ContactId = :ContactId];
    }

    //Select contact si representnant legal
    public static List<AccountContactRelation> selectContactRepLeg(Id AccountId) {
        List<AccountContactRelation> AccountContactRelationList = [SELECT AccountId,Roles,ContactId,Representant_legal__c FROM AccountContactRelation WHERE AccountId = :AccountId AND Representant_legal__c = true LIMIT 1];
        //System.debug('selectContactRepLeg : ContactId  = ' + AccountContactRelationList[0].ContactId);
        return AccountContactRelationList;
    }

    //information sur la BU
    public static Business_Unit__c businessUnit(Id BusinessUnitId) {
        return [SELECT Name,BUStreet__c,BUPostalCode__c,BUCity__c,BUCountry__c,SIRET__c,Numero_d_agrement_prefectoral__c FROM Business_Unit__c WHERE Id = :BusinessUnitId];
    }
	
    //Liste des abonnements de l'opportunité sans les status a supprimer
    public static List<Abonnement__c> abonnementList(Id recordId) {
        return [SELECT Id, Type__c, Produit__r.ProductCode, Produit__r.Name FROM Abonnement__c WHERE Opportunite__r.Id = :recordId AND Statut__c NOT IN ('Inexistant - A supprimer','Résilié')];
    }
    
    Public static void sendNotification(String emailTemplateName, Id oppId, String mail_to, String Acount1, String Acount2 ){
        OrgWideEmailAddress[] owea = [select Id from OrgWideEmailAddress where Address = 'hello@kandbaz.com'];
		EmailTemplate et = [SELECT Id, Subject, HtmlValue, Body FROM EmailTemplate WHERE DeveloperName =:emailTemplateName];
        List<string> toAddress = new List<string>();
        toAddress.add(mail_to); //add('lfranco@kandbaz.com');
        String htmlBody = et.HtmlValue;
        htmlBody = htmlBody.replace('{Acount2}', Acount2);
        htmlBody = htmlBody.replace('{Acount1}', Acount1);
        String plainBody = et.Body;
        plainBody = plainBody.replace('{Acount2}', Acount2);
        plainBody = plainBody.replace('{Acount1}', Acount1);
        
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        	mail.setTemplateId(et.Id);
            mail.setToAddresses(toAddress);
            mail.setSubject(et.subject);
            mail.setHTMLBody(et.Body);
            //mail.setTargetObjectId();
            mail.setWhatId(oppId);
            mail.setHtmlBody(htmlBody);
            mail.setPlainTextBody(plainBody);
            mail.setSaveAsActivity(true);
            mail.setUseSignature(true);
        	mail.setOrgWideEmailAddressId(owea.get(0).Id);
        List<Messaging.SingleEmailMessage> allmsg = new List<Messaging.SingleEmailMessage>();
        allmsg.add(mail);

        try {
        	Messaging.sendEmail(allmsg,false);
            //return;
        } catch (Exception e) {
            System.debug(e.getMessage());
        }
    }
}