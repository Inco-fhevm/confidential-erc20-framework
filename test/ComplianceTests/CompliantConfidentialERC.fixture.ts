import { ethers } from "hardhat";

import type { CompliantConfidentialERC20, ExampleTransferRules, Identity } from "../../types";
import { getSigners } from "../signers";

export async function deployCompliantERC20Fixture(): Promise<{
  contract: CompliantConfidentialERC20;
  identity: Identity;
  transferRules: ExampleTransferRules;
}> {
  const signers = await getSigners();

  const contractFactory = await ethers.getContractFactory("CompliantConfidentialERC20");
  const IdentityContract = await ethers.getContractFactory("Identity");
  const RulesContract = await ethers.getContractFactory("ExampleTransferRules");

  // Deploy the Identity contract
  const identity = await IdentityContract.connect(signers.alice).deploy(signers.alice.address);
  await identity.waitForDeployment();

  // Deploy the TransferRules contract
  const transferRules = await RulesContract.connect(signers.alice).deploy(identity.target);
  await transferRules.waitForDeployment();

  // Deploy the CompliantConfidentialERC20 contract
  const contract = await contractFactory
    .connect(signers.alice)
    .deploy("ConfidentialERC20", "C20", identity.target, transferRules.target);
  await contract.waitForDeployment();

  console.log(contract.target, identity.target, transferRules.target);

  // Return all contracts
  return {
    contract,
    identity,
    transferRules,
  };
}
