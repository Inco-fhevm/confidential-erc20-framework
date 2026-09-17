import { expect } from "chai";
import dotenv from "dotenv";
import fs from "fs";
import { ethers, network } from "hardhat";

import { ACL__factory } from "../types";
import { deployConfidentialERC20Fixture } from "./ConfidentialERC20Tests/confidentialerc20.fixture";
import { createInstances, decrypt64 } from "./instance";
import { getSigners, initSigners } from "./signers";

// Mock-only, normal owner mint and owner's own authorized view. No policy bypass test.
describe("Quality authorized view", function () {
  before(async function () {
    if (network.name !== "hardhat") this.skip();
    await initSigners();
  });

  async function fixture() {
    const signers = await getSigners();
    const token = await deployConfidentialERC20Fixture();
    await (await token.mint(signers.alice.address, 100)).wait();
    const address = await token.getAddress();
    const handle = await token.balanceOf(signers.alice.address);
    return { signers, token, address, handle };
  }

  it("control: minted value and both ACL grants exist with an explicit provider", async function () {
    const { signers, address, handle } = await fixture();
    const aclAddress = dotenv.parse(fs.readFileSync("node_modules/fhevm/lib/.env.acl")).ACL_CONTRACT_ADDRESS;
    const acl = ACL__factory.connect(aclAddress, ethers.provider);
    expect(await acl.persistAllowed(handle, signers.alice.address)).to.equal(true);
    expect(await acl.persistAllowed(handle, address)).to.equal(true);
    // Debug-only helper explicitly supported by this mock; not a production decryption assertion.
    expect(await decrypt64(handle)).to.equal(100n);
  });

  it("existing reencryption helper should return the owner's authorized minted balance", async function () {
    const { signers, address, handle } = await fixture();
    const instances = await createInstances(signers);
    const { publicKey, privateKey } = instances.alice.generateKeypair();
    const typed = instances.alice.createEIP712(publicKey, address);
    const signature = await signers.alice.signTypedData(
      typed.domain,
      { Reencrypt: typed.types.Reencrypt },
      typed.message,
    );
    const amount = await instances.alice.reencrypt(
      handle,
      privateKey,
      publicKey,
      signature.replace("0x", ""),
      address,
      signers.alice.address,
    );
    expect(amount).to.equal(100n);
  });
});
