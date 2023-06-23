@RestResource(urlMapping='/ADVProcedures/*')
global with sharing class ADVProcedures {

    public static List<String> Message = new List<String>();

    //Creation de la structure du json
    //Created by : Luc Franco
    global class cls_Procedure {
        public String id;
        public Date signature_date;
        public cls_participants[] participants;
        public cls_legalEntity legalEntity;
        public cls_company company;
        public cls_comptability comptability;
        public cls_reexp reexp;
        public cls_documents[] documents;
    }
    global class cls_HeaderData {
        public String RecordTypeName;
    }
    global class cls_participants {
        public String type;
        public String civility;
        public String lastName;
        public String firstName;
        public String email;
        public String mobilePhone;
        public String birthName;
        public Date birthDate;
        public String address;
        public cls_postalAddress postalAddress;
        public String id;
        public String uuid;
        public cls_documents[] documents;
    }
    global class cls_documents {
        public String label;
        public cls_files[] files;
    }
    global class cls_files {
        public String name;
        public String filedata;
    }
    global class cls_legalEntity {
        public String legalName;
        public String companyId;
    }
    global class cls_company {
        public String sage;
        public String role;
        public String name;
        public String type;
        public String delegate;
        public String form;
        public String job;
        public integer capital;
    }
    global class cls_comptability {
        public String has;
        public String type;
        public String name;
        public String road;
        public String zipcode;
        public String city;
        public String country;
    }
    global class cls_reexp {
        public String destruct;
        public String road;
        public String name;
        public integer zipcode;
        public String city;
        public String country;
    }

    global class cls_postalAddress {
        public String address1;
        public Integer postalCode;
        public String city;
        public String country;
    }

    global class metadatafile {
        public String description;
        public String nature_du_document;
        public String type_de_document;
        public Date date_la_piece;
        public String statut;
        public Boolean reception_confirmee;
        public Boolean piece_scannee;
    }
    
    @HttpPost
    global static String AdvProcedures(cls_Procedure Procedure)  {
		System.debug('Procedure    = ' + Procedure);
        //INIT value-----------------------------------------------------------------------------
        Boolean isSCAN = false;
        Boolean isREEXP = false;
        Id abonnementId;
        Id contactId;
        metadatafile metadata = new metadatafile();
        Opportunity opportunity_adv = [SELECT AccountId,BU__c FROM Opportunity WHERE Id = :Procedure.id];
        System.debug('opportunity_adv    = ' + opportunity_adv);
        Id compteId = opportunity_adv.AccountId;
        Id buId = opportunity_adv.BU__c;
        List<Abonnement__c> Listabonnements = getListAbonnements(Procedure.id);
        Abonnement__c AbonnementSCAN;

        /*
        Si destruct est vide = Il y a pas de produit SCAN donc pas de reexp trimestrielle
        Si destruct == rexp alors l'utilisateur à choisi la reexp trimestrielle
        Si destruct == destruct alors l'utilisateur souhait détruire les courriers scanner
        Pour avoir l'option "via forfait reexp", il faut que l'utilisateur ai le produit SCAN et le produit REEXP
        */

        if(Procedure.reexp.destruct != null) {
            for(Abonnement__c abonnement : Listabonnements){
                if (abonnement.Produit__r.ProductCode == 'SRV_SCAN'){isSCAN = true;abonnementId = abonnement.Id;}
                if (abonnement.Produit__r.ProductCode == 'SRV_REEXP'){isREEXP = true;}
            }
            if (Procedure.reexp.destruct == 'reexp') {
                if (isSCAN && !isREEXP) {
                    Message.add('ajout de reexp trimestrielle + date de signature');
                    AbonnementSCAN = getAbonnement(abonnementId);
                    AbonnementSCAN.option_papier_scan__c = 'reexp trimestrielle'; 
                    AbonnementSCAN.Date_option_papier_scan__c = Procedure.signature_date;
                    AbonnementSCAN.Adresse_reexp_papier_scan__c = null;
                    update AbonnementSCAN;

                }else if (isSCAN && isREEXP) {
                    Message.add('ajout de via forfait reexp + date de signature + adresse de reexpedition');
                    AbonnementSCAN = getAbonnement(abonnementId);
                    AbonnementSCAN.option_papier_scan__c = 'via forfait reexp'; 
                    AbonnementSCAN.Date_option_papier_scan__c = Procedure.signature_date;
                    AbonnementSCAN.Adresse_reexp_papier_scan__c = Procedure.reexp.road+' '+Procedure.reexp.zipcode+' '+Procedure.reexp.city+' '+Procedure.reexp.country;
                    update AbonnementSCAN;

                }
            } else if (Procedure.reexp.destruct == 'destruct' && isSCAN) {
                Message.add('ajout de destruction + date de signature');
                AbonnementSCAN = getAbonnement(abonnementId);
                AbonnementSCAN.option_papier_scan__c = 'destruction';
                AbonnementSCAN.Date_option_papier_scan__c = Procedure.signature_date;
                AbonnementSCAN.Adresse_reexp_papier_scan__c = null;
                update AbonnementSCAN;
            }
        }

        //Gestion du compte/comptabilite------------------------------------------------------------
        Account account = [SELECT Name,Ownership,Capital_social_en_euros__c, Expert_comptable__c, Adresse_de_tenue_de_la_comptabilit__c FROM Account WHERE Id = :compteId];
        account.Name = Procedure.company.name;
        account.Ownership = Procedure.company.form;
        account.Capital_social_en_euros__c = Procedure.company.capital;
        if (Procedure.comptability.has == 'yes') {
            Id IdAccount = setExpertComptable(Procedure.comptability, opportunity_adv.BU__c);
            Message.add('Id comptable = '+IdAccount);
            account.Expert_comptable__c = IdAccount; //Procedure.comptability.name;
            account.Adresse_de_tenue_de_la_comptabilit__c = Procedure.comptability.road+' '+Procedure.comptability.zipcode+' '+Procedure.comptability.city+' '+Procedure.comptability.country;
        }
        update account;
 
        /* BOUCLE SUR LES PARTICIPANTS--------------------------*/
        for (cls_participants participant : Procedure.participants) {
                Message.add('type = ' + participant.type);
                //Gestion contact------------------------------------------------
                if (participant.id != null){
                    contactId = participant.id;
                    Updatecontact(participant, compteId, participant.id); 
                } else {
                    Message.add(participant.id+' '+participant.type+' '+participant.lastName);
                    if (participant.type != 'hebergeur'){
                        participant.id = Createcontact(participant, compteId);
                    }
                }

            /* BOUCLE SUR LES DOCUMENTS DU PARTICIPANT EN COURS--------------------------*/
            if(participant.documents!=null && !participant.documents.isEmpty()) {
                for (cls_documents document : participant.documents){

                    Id PieceAdminId = null;
                    String label = document.label.trim();
                    String prefix = participant.type + ' - ';// == 'hebergeur' ? 'hebergeur ' : '';
                    Message.add('label = ' + label + ' ' + prefix);
                    for (cls_files file : document.files){
                        Message.add('PieceAdminId = ' + PieceAdminId);


                        if (label == 'Carte d\'identité'){
                            metadata.description = prefix + label;
                            metadata.nature_du_document = 'Pièce d\'identité';
                            metadata.type_de_document = 'CNI';
                            metadata.date_la_piece = system.today();
                            metadata.statut = 'Approuvée';
                            metadata.reception_confirmee = true;
                            metadata.piece_scannee = true;
                        }
                        if (label == 'Passeport'){
                            metadata.description = prefix + 'Passeport';
                            metadata.nature_du_document = 'Pièce d\'identité';
                            metadata.type_de_document = 'Passeport';
                            metadata.date_la_piece = system.today();
                            metadata.statut = 'Approuvée';
                            metadata.reception_confirmee = true;
                            metadata.piece_scannee = true;
                        }
                        if (label == 'Titre de séjour'){
                            metadata.description = prefix + 'Titre de séjour';
                            metadata.nature_du_document = 'Pièce d\'identité';
                            metadata.type_de_document = 'Titre de séjour';
                            metadata.date_la_piece = system.today();
                            metadata.statut = 'Approuvée';
                            metadata.reception_confirmee = true;
                            metadata.piece_scannee = true;
                        }
                        if (label == 'Carte vitale'){
                            metadata.description = prefix + 'Carte vitale';
                            metadata.nature_du_document = 'Pièce d\'identité';
                            metadata.type_de_document = 'Carte vitale';
                            metadata.date_la_piece = system.today();
                            metadata.statut = 'Approuvée';
                            metadata.reception_confirmee = true;
                            metadata.piece_scannee = true;
                        }
                        if (label == 'Avis d\'imposition'){
                            metadata.description = prefix + 'Avis d\'imposition';
                            metadata.nature_du_document = 'Attestation fiscale';
                            metadata.type_de_document = 'Avis d\'imposition';
                            metadata.date_la_piece = system.today();
                            metadata.statut = 'Approuvée';
                            metadata.reception_confirmee = true;
                            metadata.piece_scannee = true;
                        }
                        if (label == 'Permis de conduire (nouveau format)'){
                            metadata.description = prefix + 'Permis de conduire';
                            metadata.nature_du_document = 'Pièce d\'identité';
                            metadata.type_de_document = 'Permis de conduire';
                            metadata.date_la_piece = system.today();
                            metadata.statut = 'Approuvée';
                            metadata.reception_confirmee = true;
                            metadata.piece_scannee = true;
                        }
                        if (label == 'Permis de conduire (ancien format)'){
                            metadata.description = prefix + 'Permis de conduire';
                            metadata.nature_du_document = 'Pièce d\'identité';
                            metadata.type_de_document = 'Permis de conduire';
                            metadata.date_la_piece = system.today();
                            metadata.statut = 'Approuvée';
                            metadata.reception_confirmee = true;
                            metadata.piece_scannee = true;
                        }
                        if (label == 'Récépissé'){
                            metadata.description = prefix + 'Récépissé';
                            metadata.nature_du_document = 'Justificatif de domicile';
                            metadata.type_de_document = 'Récépissé';
                            metadata.date_la_piece = system.today();
                            metadata.statut = 'Approuvée';
                            metadata.reception_confirmee = true;
                            metadata.piece_scannee = true;
                        }
                        if (label == 'Kbis'){
                            metadata.description = prefix + 'Extrait Kbis';
                            metadata.nature_du_document = 'Statuts / Extrait Kbis';
                            metadata.type_de_document = 'Extrait Kbis';
                            metadata.date_la_piece = system.today();
                            metadata.statut = 'Approuvée';
                            metadata.reception_confirmee = true;
                            metadata.piece_scannee = true;
                        }
                        if (label == 'Facture ou échéancier d\'un fournisseur (eau, électricité, téléphonie, etc.)'){
                            metadata.description = prefix + label;
                            metadata.nature_du_document = 'Justificatif de domicile';
                            metadata.type_de_document = '';
                            metadata.date_la_piece = system.today();
                            metadata.statut = 'Approuvée';
                            metadata.reception_confirmee = true;
                            metadata.piece_scannee = true;
                        }     
                        if (label == 'Avis ou justificatif d\'imposition'){
                            metadata.description = prefix + 'Avis ou justificatif d\'imposition';
                            metadata.nature_du_document = 'Attestation fiscale';
                            metadata.type_de_document = 'Avis ou justificatif d\'imposition';
                            metadata.date_la_piece = system.today();
                            metadata.statut = 'Approuvée';
                            metadata.reception_confirmee = true;
                            metadata.piece_scannee = true;
                        }
                        if (label == 'Taxe foncière'){
                            metadata.description = prefix + 'Taxe foncière';
                            metadata.nature_du_document = 'Attestation fiscale';
                            metadata.type_de_document = 'Taxe foncière';
                            metadata.date_la_piece = system.today();
                            metadata.statut = 'Approuvée';
                            metadata.reception_confirmee = true;
                            metadata.piece_scannee = true;
                        }
                        if (label == 'Taxe d\'habitation'){
                            metadata.description = prefix + 'Taxe d\'habitation';
                            metadata.nature_du_document = 'Attestation fiscale';
                            metadata.type_de_document = 'Taxe d\'habitation';
                            metadata.date_la_piece = system.today();
                            metadata.statut = 'Approuvée';
                            metadata.reception_confirmee = true;
                            metadata.piece_scannee = true;
                        }
                        if (label == 'Relevé CAF'){
                            metadata.description = prefix + 'Relevé CAF';
                            metadata.nature_du_document = 'Attestation fiscale';
                            metadata.type_de_document = 'Relevé CAF';
                            metadata.date_la_piece = system.today();
                            metadata.statut = 'Approuvée';
                            metadata.reception_confirmee = true;
                            metadata.piece_scannee = true;
                        }
                        if (label == 'Attestation hébergement'){
                            metadata.description = prefix + 'Attestation hébergement';
                            metadata.nature_du_document = 'Justificatif de domicile';
                            metadata.type_de_document = 'Attestation hébergement';
                            metadata.date_la_piece = system.today();
                            metadata.statut = 'Approuvée';
                            metadata.reception_confirmee = true;
                            metadata.piece_scannee = true;
                        }
                        if (label == 'Projets Statuts'){
                            metadata.description = prefix + 'Projets Statuts';
                            metadata.nature_du_document = 'Statuts / Extrait Kbis';
                            metadata.type_de_document = 'Projets Statuts';
                            metadata.date_la_piece = system.today();
                            metadata.statut = 'Approuvée';
                            metadata.reception_confirmee = true;
                            metadata.piece_scannee = true;
                        }
                        if (label == 'Mandat'){
                            metadata.description = prefix + 'Mandat';
                            metadata.nature_du_document = 'Attestation';
                            metadata.type_de_document = 'Mandat';
                            metadata.date_la_piece = system.today();
                            metadata.statut = 'Approuvée';
                            metadata.reception_confirmee = true;
                            metadata.piece_scannee = true;
                        }

                        // AJOUT DE LA PIECE ADMIN
                        if (PieceAdminId != null) {
                            SetFileAdmin(file, metadata, opportunity_adv.AccountId, participant.id, PieceAdminId);
                        } else {
                            PieceAdminId = SetPieceAdmin(metadata, opportunity_adv.AccountId, participant.id);
                            SetFileAdmin(file, metadata, opportunity_adv.AccountId, participant.id, PieceAdminId);
                        }
                    }
                }
            }
        }

        /* BOUCLE SUR LES DOCUMENTS DU DOSSIER--------------------------*/
        if(Procedure.documents!=null && !Procedure.documents.isEmpty()) {
            for (cls_documents document : Procedure.documents){
                Message.add('Procedure participant document label = ' + document.label);
                Id PieceAdminId = null;
                for (cls_files file : document.files){
                    Message.add('Procedure participant document file name = ' + file.name);

                    if (document.label == 'Contrat de domiciliation') {
                        metadata.description = document.label;
                        metadata.nature_du_document = 'Contrat';
                        metadata.type_de_document = '';
                        metadata.date_la_piece = system.today();
                        metadata.statut = 'Approuvée';
                        metadata.reception_confirmee = true;
                        metadata.piece_scannee = true;
                    }
                    if (document.label == 'Procuration postale') {
                        metadata.description = document.label;
                        metadata.nature_du_document = 'Procuration postale';
                        metadata.type_de_document = '';
                        metadata.date_la_piece = system.today();
                        metadata.statut = 'Approuvée';
                        metadata.reception_confirmee = true;
                        metadata.piece_scannee = true;
                    }

                    // AJOUT DE LA PIECE ADMIN
                    PieceAdminId = SetPieceAdmin(metadata, opportunity_adv.AccountId, null);
                    SetFileAdmin(file, metadata, opportunity_adv.AccountId, null, PieceAdminId);

                }
            }
        }

        //Creation de la personnemorale------------------------------------------------------------------------------------------------
        if (Procedure.legalEntity != null) {
            Message.add('legalEntity = '+ Procedure.legalEntity.legalName);
            //Creation du compte personne morale
            Account Personne_morale = new Account(Name = Procedure.legalEntity.legalName, SIREN__c = Procedure.legalEntity.companyId);
            insert Personne_morale;

            //Creation de la relation compte personne morale sur le contact
            AccountContactRelation Relation = new AccountContactRelation(
                AccountId = Personne_morale.Id,
                ContactId = contactId,
                Roles = 'Représentant légal',
                Representant_legal__c = true,
                IsActive = true);
                insert Relation;
           
            //Modification du compte de la procedure
            Account account_adv = [SELECT ParentId FROM Account WHERE Id = :compteId];
            account_adv.ParentId = Personne_morale.Id;
            update account_adv;
        }


        return JSON.serialize(Message);
    }

//-----------------------------------------------------------------------------------------------------------------------------------------

public static Id Createcontact(cls_participants contact, Id AccountId){
    Contact SetContact = new Contact(
    AccountId = AccountId,
    Salutation = contact.civility,
    FirstName = contact.lastName,
    LastName = contact.firstName,
    Email = contact.email,
    MobilePhone = contact.mobilePhone,
    Birthname__c = contact.birthName,
    Birthdate = contact.birthDate
    );
    insert SetContact;

    AccountContactRelation Relation = new AccountContactRelation(
        AccountId = AccountId,
        ContactId= SetContact.Id,
        Representant_legal__c = true,
        Roles = contact.type.capitalize()
    );
    return SetContact.Id;
}

//-----------------------------------------------------------------------------------------------------------------------------------------

public static void Updatecontact(cls_participants contact, Id AccountId, Id ContactId){
    System.debug('ContactId = ' + ContactId);
    Contact getContact = [SELECT Birthdate,Birthname__c,MobilePhone,Email,LastName,FirstName,Salutation FROM Contact WHERE Id = :ContactId LIMIT 1];
    getContact.Salutation = contact.civility;
    getContact.FirstName = contact.lastName;
    getContact.LastName = contact.firstName;
    getContact.Email = contact.email;
    getContact.MobilePhone = contact.mobilePhone;
    getContact.Birthname__c = contact.birthName;
    getContact.Birthdate = contact.birthDate;
    update getContact;

    AccountContactRelation Relation =[SELECT AccountId,ContactId,Representant_legal__c,Roles FROM AccountContactRelation WHERE ContactId = :ContactId AND AccountId = :AccountId];
    Relation.Representant_legal__c = true;
    Relation.Roles = 'Représentant légal';
    update Relation;
}  

//-----------------------------------------------------------------------------------------------------------------------------------------

// Ajout de la piece administrative----------------------------------
public static Id SetPieceAdmin(metadatafile metadata, Id AccountId, Id ContacttId) {
    //Generation de la piece administrative----------------------------------
    Pieces_administratives__c PieceAdmin = new Pieces_administratives__c(
        Compte__c = AccountId,
        Contact__c = ContacttId,
        Description__c = metadata.description,
        Nature_du_document__c = metadata.nature_du_document,
        Type_de_document__c = metadata.type_de_document,
        Date_la_piece__c = metadata.date_la_piece,
        Statut__c = metadata.statut,
        Reception_confirmee__c = true,
        Piece_scannee__c = true);
    insert PieceAdmin;
    return PieceAdmin.Id;
}

// Ajout du fichier physique dans SF----------------------------------
public static void SetFileAdmin(cls_files file, metadatafile metadata, Id AccountId, Id ContactId, Id PieceAdminId) {

    Integer charLength = file.name.length();
    String fileExtention = file.name.substring((charLength-4), charLength);
        
    //Sauvegarde du fichier
    ContentVersion conVer = new ContentVersion();
    conVer.ContentLocation = 'S'; // to use S specify this document is in Salesforce, to use E for external files
    conVer.PathOnClient = metadata.type_de_document+'_'+AccountId+'_'+ContactId+'_'+fileExtention; // The files name, extension is very important here which will help the file in preview.
    conVer.Title = metadata.nature_du_document; // Display name of the files
    conVer.VersionData = EncodingUtil.base64Decode(file.filedata);  // From String to Blob
    insert conVer;    //Insert ContentVersion

    // First get the Content Document Id from ContentVersion Object
    Id conDoc = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =:conVer.Id].ContentDocumentId;
    //create ContentDocumentLink  record 
    ContentDocumentLink conDocLink = New ContentDocumentLink();
    conDocLink.LinkedEntityId = PieceAdminId; //numExtraitPappers[0].Id; //PieceAdmin.Id; // Specify RECORD ID here i.e Any Object ID (Standard Object/Custom Object)
    conDocLink.ContentDocumentId = conDoc;  //ContentDocumentId Id from ContentVersion
    conDocLink.shareType = 'V';
    insert conDocLink;
}


    public static List<Abonnement__c> getListAbonnements(Id OpportunityId) {
        List<Abonnement__c> abonnement_adv = [SELECT Id,Compte__c,Produit__r.Name,Produit__r.ProductCode,Produit__r.Id,Produit__r.Type__c,Produit__r.RecordType.Name FROM Abonnement__c WHERE Opportunite__c = :OpportunityId];
        return abonnement_adv;
    }

    public static Abonnement__c getAbonnement(Id AbonnementId) {
        Abonnement__c Abonnement = [SELECT option_papier_scan__c, Date_option_papier_scan__c,Adresse_reexp_papier_scan__c FROM Abonnement__c WHERE Id = :AbonnementId LIMIT 1];
        return Abonnement;
    }

    public static Id setExpertComptable(cls_comptability value_account, Id IdBU) {
        String adresse = value_account.road+' '+value_account.zipcode+' '+value_account.city+' '+value_account.country;

        List<Account> getexpertComptable = [SELECT Id FROM Account WHERE 
            Name = :value_account.name AND 
            Adresse_du_si_ge_social__c = :adresse AND
            Industry = 'Expert comptable'];

        if(!getexpertComptable.isEmpty()) {
            //Message.add('select Comptable' + getexpertComptable[0].Name+' '+getexpertComptable[0].Id);
            return getexpertComptable[0].Id;
        } else {
            Account expertComptable = new Account(
                Name = value_account.name,
                BU__c = IdBU,
                Adresse_du_si_ge_social__c = adresse,
                Industry = 'Expert comptable' 
            );
            insert expertComptable;
            //Message.add('insert Comptable' + value_account.name+' '+expertComptable.Id);
            return expertComptable.Id;
        }
        
    }

}