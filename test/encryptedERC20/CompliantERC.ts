import { expect } from "chai";
import "hardhat";
import { createInstances } from "../instance";
import { getSigners, initSigners } from "../signers";
import { deployCompliantERC20Fixture } from "./CompliantERC.fixture";

describe("CompliantConfidentialERC20 Contract Tests", function () {
  before(async function () {
    // Initialize signers and set them for future use
    await initSigners();
    this.signers = await getSigners();
  });

  beforeEach(async function () {
    // Deploy the ERC20, Identity, and TransferRules contracts
    const { contract, identity, transferRules } = await deployCompliantERC20Fixture();

    // Store the contract address and instance for future use
    this.contractAddress = await contract.getAddress();
    this.erc20 = contract;
    this.identity = identity;
    this.identityAddress = await identity.getAddress();
    this.transferRules = transferRules;
    this.transferRulesAddresss = transferRules.getAddress();
    // Create instances for the testing environment
    this.instances = await createInstances(this.signers);
    const transaction = await this.erc20.mint(this.signers.alice.address, 1000);
    await transaction.wait();
    const input = this.instances.alice.createEncryptedInput(this.identityAddress, this.signers.alice.address);
    input.add8(29);
    const encryptedCode = input.encrypt();

    // Update Alice's identity
    const updateAliceCodeTx = await this.identity.registerIdentity(
      this.signers.alice.address,
      encryptedCode.handles[0],
      encryptedCode.inputProof,
    );
    await updateAliceCodeTx.wait();
    const inputBob = this.instances.bob.createEncryptedInput(this.identityAddress, this.signers.bob.address);
    inputBob.add8(25);
    const encryptedCodeBob = inputBob.encrypt();
    const updateBobCodeTx = await this.identity.registerIdentity(
      this.signers.bob.address,
      encryptedCodeBob.handles[0],
      encryptedCodeBob.inputProof,
    );
    const setAgeLimitTx = await this.transferRules.setMinimumAge(18);
    await setAgeLimitTx.wait();
    await updateBobCodeTx.wait();
  });

  it("Should deploy CompliantConfidentialERC20, Identity, and TransferRules contracts", async function () {
    // Check if the contract, identity, and transfer rules were deployed

    const totalSupply = await this.erc20.totalSupply();
    expect(totalSupply).to.equal(1000);
    console.log("Contracts deployed successfully.");
  });
  it("Should transfer token from alice to Bob", async function () {
    const input = this.instances.alice.createEncryptedInput(this.contractAddress, this.signers.alice.address);
    input.add64(100);
    const encryptedTransferAmount = input.encrypt();
    const tx = await this.erc20["transfer(address,bytes32,bytes)"](
      this.signers.bob.address,
      encryptedTransferAmount.handles[0],
      encryptedTransferAmount.inputProof,
    );
    await tx.wait();
    // Reencrypt Alice's balance
    const balanceHandleAlice = await this.erc20.balanceOf(this.signers.alice);
    const { publicKey: publicKeyAlice, privateKey: privateKeyAlice } = this.instances.alice.generateKeypair();
    const eip712 = this.instances.alice.createEIP712(publicKeyAlice, this.contractAddress);
    const signatureAlice = await this.signers.alice.signTypedData(
      eip712.domain,
      { Reencrypt: eip712.types.Reencrypt },
      eip712.message,
    );
    const balanceAlice = await this.instances.alice.reencrypt(
      balanceHandleAlice,
      privateKeyAlice,
      publicKeyAlice,
      signatureAlice.replace("0x", ""),
      this.contractAddress,
      this.signers.alice.address,
    );

    expect(balanceAlice).to.equal(1000 - 100);
  });

  it("Should check for transfer rules", async function () {
    const input = this.instances.alice.createEncryptedInput(this.contractAddress, this.signers.alice.address);
    input.add64(100);
    const encryptedTransferAmount = input.encrypt();
    const tx = await this.transferRules["transfer(address,address,bytes32,bytes)"](
      this.signers.alice.address,
      this.signers.bob.address,
      encryptedTransferAmount.handles[0],
      encryptedTransferAmount.inputProof,
    );
    await tx.wait();

    // reencrypt code
  });

  it("Should not change balance of Bob or Alice if Bob is blacklisted", async function () {
    await this.transferRules.setBlacklist(this.signers.bob.address, true);

    const input = this.instances.alice.createEncryptedInput(this.contractAddress, this.signers.alice.address);
    input.add64(100);
    const encryptedTransferAmount = input.encrypt();

    const tx = await this.erc20["transfer(address,bytes32,bytes)"](
      this.signers.bob.address,
      encryptedTransferAmount.handles[0],
      encryptedTransferAmount.inputProof,
    );
    await tx.wait();
    const balanceHandleAlice = await this.erc20.balanceOf(this.signers.alice);
    const { publicKey: publicKeyAlice, privateKey: privateKeyAlice } = this.instances.alice.generateKeypair();
    const eip712 = this.instances.alice.createEIP712(publicKeyAlice, this.contractAddress);
    const signatureAlice = await this.signers.alice.signTypedData(
      eip712.domain,
      { Reencrypt: eip712.types.Reencrypt },
      eip712.message,
    );
    const balanceAlice = await this.instances.alice.reencrypt(
      balanceHandleAlice,
      privateKeyAlice,
      publicKeyAlice,
      signatureAlice.replace("0x", ""),
      this.contractAddress,
      this.signers.alice.address,
    );
    //balance should not change as bob is blacklisted
    expect(balanceAlice).to.equal(1000);
  });
});
