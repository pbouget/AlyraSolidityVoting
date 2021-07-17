// SPDX-License-Identifier: MIT 
pragma solidity >=0.6.11 <0.9.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

/**
 * @title Système de vote
 * @author Philippe Bouget
 * @dev réalisé pour le Défi Système de vote (Alyra) - v1.0
 */
contract Voting is Ownable {
 
    uint public winningProposalId; // id du gagnant
    
    uint public totalOfVotes; // on stocke le nombre total des votes 
    
    WorkflowStatus public workflowStatus; // permet de connaître le status à tout moment (de 0 à 5)
    
    mapping(address => Voter) public whitelist; // liste des votants enregistrés par l'admin
    
     // un votant
    struct Voter
        {
            bool isRegistered;          // est enregistré
            bool hasVoted;              // a voté
            uint votedProposalId;       // pour
        }

    // un candidat
    struct Proposal
        {
            string description;         // nom du candidat ou autre
            uint voteCount;             // nombre des votes comptabilisés
        }
    
    // liste des candidats proposés sous forme de tableau
    // une autre écriture est aussi possible : mapping(uint => Proposal) public candidats;
    Proposal[] public candidats;
        
    // enum des différents états possible pendant la mise en place du vote 
    enum WorkflowStatus
        {
            RegisteringVoters,
            ProposalsRegistrationStarted,
            ProposalsRegistrationEnded,
            VotingSessionStarted,
            VotingSessionEnded,
            VotesTallied
        }
 
    // liste des events
 
    event VoterRegistered(address voterAddress);        
    event ProposalsRegistrationStarted();               
    event ProposalsRegistrationEnded();                 
    event ProposalRegistered(uint proposalId);          
    event VotingSessionStarted();                       
    event VotingSessionEnded();                         
    event Voted (address voter, uint proposalId);
    event VotesTallied();
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);


  constructor() Ownable() {
      
      workflowStatus = WorkflowStatus.RegisteringVoters; // status par défaut à l'instanciation
      //candidats.push(Proposal('Vote Blanc', 0)); // on pourrait ajouter un "vote blanc" par défaut (facultaif)
  }
  
  /* liste de fonctions appelées uniquement par l'Admin qui gère le déroulement complet.
     On pourrait le faire avec une seule méthode en passant le numéro du workflowStatus en paramètre.
     Pour le fun, j'ai préféré créer des méthodes distinctes, c'est plus clair pour tester.
  */

  function sessionProposalStarted() public onlyAdmin {
      
      workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
      emit ProposalsRegistrationStarted();
      emit WorkflowStatusChange(workflowStatus, WorkflowStatus.ProposalsRegistrationStarted);
  }
  
  function sessionProposalEnded() public onlyAdmin {
      
      workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
      emit ProposalsRegistrationEnded();
      emit WorkflowStatusChange(workflowStatus, WorkflowStatus.ProposalsRegistrationEnded);
  }
  
  function votingSessionStarted() public onlyAdmin {
      
      workflowStatus = WorkflowStatus.VotingSessionStarted;
      emit VotingSessionStarted();
      emit WorkflowStatusChange(workflowStatus, WorkflowStatus.VotingSessionStarted);
      
  }
  
  function votingSessionEnded() public onlyAdmin {
      
      workflowStatus = WorkflowStatus.VotingSessionEnded;
      emit VotingSessionEnded();
      emit WorkflowStatusChange(workflowStatus, WorkflowStatus.VotingSessionEnded);
  }
  
  
  /**
   *  @dev Méthode pour comptabiliser les votes et déterminer le gagnant
   */
   function votesTallied() public onlyAdmin {
       
        require(workflowStatus == WorkflowStatus.VotingSessionEnded, "La Session de vote est toujours ouverte !");
        workflowStatus = WorkflowStatus.VotesTallied; // on change le status

        uint winnerId; // gagnat en cours
        uint winningVoteCount; // nombre de vote du gagnant

        for(uint i = 0; i < candidats.length; i++)
        {
            if (candidats[i].voteCount > winningVoteCount)
            {
                winningVoteCount = candidats[i].voteCount; // on récupère le total des votes pour un candidat donné
                winnerId = i; // on initialise l'id du gagnant en cours
            }
            totalOfVotes += candidats[i].voteCount; // on comptabilise les votes de chaque candidat
        }
        winningProposalId = winnerId;   // id du gagnant déclaré en variable du contrat
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotesTallied);
        emit VotesTallied();
        
    }

  /**
   * @dev Méthode pour retourner les informations sur le gagnant du vote
   * @return winnerId : l'identifiant du gagnant
   * @return description : nom ou pseudo du/de la candidat.e
   * @return voteCount : nombre de votes du gagnant
   * @return totalVotes : total des votes
   */
  function theWinnerIs() public canDo(WorkflowStatus.VotesTallied) view returns(uint winnerId, string memory description, uint voteCount, uint totalVotes)
    {
        return (
                    winningProposalId,
                    candidats[winningProposalId].description,
                    candidats[winningProposalId].voteCount,
                    totalOfVotes
               );
    }
  
  /*
   * @dev Méthode qui permet à l'admin d'enregistrer des adresses de votants dans la whitelist
   * @param : _address du votant à enregistrer
   */
  function addVoterToWhitelist(address _address) public onlyAdmin {
      
      require(workflowStatus == WorkflowStatus.RegisteringVoters, "RegisteringVoters indispensable");        
      require(!whitelist[_address].isRegistered, "Votant existe dans la whitelist");
        
      whitelist[_address].isRegistered = true;  // est enregistré
      whitelist[_address].hasVoted = false;     // mais n'a pas encore voté
      workflowStatus = WorkflowStatus.RegisteringVoters;
      emit VoterRegistered(_address);           // on génère un event lié à l"enregistrement d'un nouveau votant
  }
  
  
  /*
   * @dev Méthode qui permet à un votant présent dans la whitelist de voter en passant l'id du candidat
   * @param : _proposalId : l'id du candidat
   */
  function vote(uint _proposalId) public canDo(WorkflowStatus.VotingSessionStarted)
  {
      address votant = msg.sender;
      // un votant fait son choix, on vérifie s'il peut voter, il ne doit pas être admin.

      if (whitelist[votant].isRegistered == true && whitelist[votant].hasVoted == false && votant != owner())
      {
          whitelist[votant].hasVoted = true;
          whitelist[votant].votedProposalId = _proposalId;
          emit Voted(votant, _proposalId);
          candidats[_proposalId].voteCount++;
      }
      emit Voted(votant, _proposalId);    
  }
  
  /*
   * @dev Méthode qui permet la proposition d'un candidat
   * @param : _description : nom ou pseudo du/de la candidat.e
   */
  function proposerCandidat(string memory _description) public canDo(WorkflowStatus.ProposalsRegistrationStarted) {
     
     address votant = msg.sender;
     if (whitelist[votant].isRegistered == true && votant != owner())
     {
         candidats.push(Proposal(_description, 0)); // on ajoute le nouveau candidat
         uint proposalId = candidats.length-1;      // on détermine son id
         emit ProposalRegistered(proposalId);       // on émet un event
      }
  }
  
    
    modifier onlyAdmin() { 
       require(msg.sender == owner(),"Seul l'admin peut appeler cette fonction !");
       _;
   }
   
    modifier canDo(WorkflowStatus _workflowStatus)
    { 
       require(workflowStatus == _workflowStatus,"Le status en cours ne permet pas cette action  !");
       _;
    }
    
}