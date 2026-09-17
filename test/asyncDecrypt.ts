import dotenv from "dotenv";
import { LogDescription } from "ethers";
import fs from "fs";
import hre, { ethers, network } from "hardhat";

import { ACL__factory, GatewayContract__factory } from "../types";
import { awaitCoprocessor, getClearText } from "./coprocessorUtils";
import { waitNBlocks } from "./utils";

const networkName = network.name;

const parsedEnvACL = dotenv.parse(fs.readFileSync("node_modules/fhevm/lib/.env.acl"));
const aclAdd = parsedEnvACL.ACL_CONTRACT_ADDRESS.replace(/^0x/, "").replace(/^0+/, "").toLowerCase();

const CiphertextType = {
  0: "bool",
  1: "uint8", // corresponding to euint4
  2: "uint8", // corresponding to euint8
  3: "uint16",
  4: "uint32",
  5: "uint64",
  6: "uint128",
  7: "address",
  11: "bytes",
};

function isCipherTextType(type: number): type is keyof typeof CiphertextType {
  return type in CiphertextType;
}

function mustGetCipherTextType(type: number): keyof typeof CiphertextType {
  if (!isCipherTextType(type)) {
    throw new Error(`Invalid ciphertext type: ${type}`);
  }
  return type;
}

const currentTime = (): string => {
  const now = new Date();
  return now.toLocaleTimeString("en-US", { hour12: true, hour: "numeric", minute: "numeric", second: "numeric" });
};

const parsedEnv = dotenv.parse(fs.readFileSync("node_modules/fhevm/gateway/.env.gateway"));
const privKeyRelayer = process.env.PRIVATE_KEY_GATEWAY_RELAYER;
const relayer = new ethers.Wallet(privKeyRelayer!, ethers.provider);

const ifaceEventDecryption = new ethers.Interface([
  "event EventDecryption(uint256 indexed requestID, uint256[] cts, address contractCaller, bytes4 callbackSelector, uint256 msgValue, uint256 maxTimestamp, bool passSignaturesToCaller)",
]);

const gateway = GatewayContract__factory.connect(parsedEnv.GATEWAY_CONTRACT_PREDEPLOY_ADDRESS, ethers.provider);

const ifaceResultCallback = GatewayContract__factory.createInterface();
let firstBlockListening: number;
let lastBlockSnapshotForDecrypt: number;

export const asyncDecrypt = async (): Promise<void> => {
  firstBlockListening = await ethers.provider.getBlockNumber();
  if (networkName === "hardhat" && !hre.__SOLIDITY_COVERAGE_RUNNING) {
    // evm_snapshot is not supported in coverage mode
    await ethers.provider.send("set_lastBlockSnapshotForDecrypt", [firstBlockListening]);
  }
  // this function will emit logs for every request and fulfilment of a decryption

  await gateway.on(
    gateway.getEvent("EventDecryption"),
    async (requestID, cts, contractCaller, callbackSelector, msgValue, maxTimestamp, passSignaturesToCaller, log) => {
      const blockNumber = log.blockNumber;
      console.log(`${await currentTime()} - Requested decrypt on block ${blockNumber} (requestID ${requestID})`);
    },
  );
  await gateway.on(gateway.getEvent("ResultCallback"), async (requestID, success, result, log) => {
    const blockNumber = log.blockNumber;
    console.log(`${await currentTime()} - Fulfilled decrypt on block ${blockNumber} (requestID ${requestID})`);
  });
};

export const awaitAllDecryptionResults = async (): Promise<void> => {
  const provider = ethers.provider;
  if (networkName === "hardhat" && !hre.__SOLIDITY_COVERAGE_RUNNING) {
    // evm_snapshot is not supported in coverage mode
    lastBlockSnapshotForDecrypt = await provider.send("get_lastBlockSnapshotForDecrypt");
    if (lastBlockSnapshotForDecrypt < firstBlockListening) {
      firstBlockListening = lastBlockSnapshotForDecrypt + 1;
    }
  }
  await fulfillAllPastRequestsIds(networkName === "hardhat");
  firstBlockListening = (await ethers.provider.getBlockNumber()) + 1;
  if (networkName === "hardhat" && !hre.__SOLIDITY_COVERAGE_RUNNING) {
    // evm_snapshot is not supported in coverage mode
    await provider.send("set_lastBlockSnapshotForDecrypt", [firstBlockListening]);
  }
};

const getAlreadyFulfilledDecryptions = async (): Promise<bigint[]> => {
  let results: (null | LogDescription)[] = [];
  const eventDecryptionResult = await gateway.filters.ResultCallback().getTopicFilter();
  const filterDecryptionResult = {
    address: process.env.GATEWAY_CONTRACT_PREDEPLOY_ADDRESS,
    fromBlock: firstBlockListening,
    toBlock: "latest",
    topics: eventDecryptionResult,
  };
  const pastResults = await ethers.provider.getLogs(filterDecryptionResult);
  results = results.concat(pastResults.map((result) => ifaceResultCallback.parseLog(result)));

  return results.filter((r): r is LogDescription => !!r).map((r) => BigInt(r?.args[0]));
};

const allTrue = (arr: boolean[], fn = Boolean) => arr.every(fn);

const fulfillAllPastRequestsIds = async (mocked: boolean) => {
  const eventDecryption = await gateway.filters.EventDecryption().getTopicFilter();
  const results = await getAlreadyFulfilledDecryptions();
  const filterDecryption = {
    address: process.env.GATEWAY_CONTRACT_PREDEPLOY_ADDRESS,
    fromBlock: firstBlockListening,
    toBlock: "latest",
    topics: eventDecryption,
  };
  const pastRequests = await ethers.provider.getLogs(filterDecryption);
  for (const request of pastRequests) {
    const event = ifaceEventDecryption.parseLog(request);
    if (!event) {
      throw new Error(`Could not parse event: ${request}`);
    }
    // TODO: get strongly typed event, this should be possible from typechain
    const requestID = event.args[0];
    const handles = event.args[1] as (number | bigint | string)[];
    const typesList = handles.map((handle) => parseInt(handle.toString(16).slice(-4, -2), 16));
    const msgValue = event.args[4];
    if (!results.includes(requestID)) {
      // if request is not already fulfilled
      if (mocked) {
        // in mocked mode, we trigger the decryption fulfillment manually
        await awaitCoprocessor();

        // first check that all handles are allowed for decryption
        const acl = ACL__factory.connect(`0x${aclAdd}`, ethers.provider);
        const isAllowedForDec = await Promise.all(handles.map(async (handle) => acl.allowedForDecryption(handle)));
        if (!allTrue(isAllowedForDec)) {
          throw new Error("Some handle is not authorized for decryption");
        }

        const types = typesList.map((num) => CiphertextType[mustGetCipherTextType(num)]);
        const values = await Promise.all(handles.map(async (handle) => BigInt(await getClearText(BigInt(handle)))));
        const valuesFormatted = values.map((value, index) =>
          types[index] === "address" ? "0x" + value.toString(16).padStart(40, "0") : value,
        );
        const valuesFormatted2 = valuesFormatted.map((value, index) =>
          types[index] === "bytes" ? "0x" + value.toString(16).padStart(512, "0") : value,
        );

        const abiCoder = new ethers.AbiCoder();
        const encodedData = abiCoder.encode(["uint256", ...types], [31, ...valuesFormatted2]); // 31 is just a dummy uint256 requestID to get correct abi encoding for the remaining arguments (i.e everything except the requestID)
        const calldata = "0x" + encodedData.slice(66); // we just pop the dummy requestID to get the correct value to pass for `decryptedCts`

        const tx = await gateway.connect(relayer).fulfillRequest(requestID, calldata, [], { value: msgValue });
        await tx.wait();
      } else {
        // in fhEVM mode we must wait until the gateway service relayer submits the decryption fulfillment tx
        await waitNBlocks(1);
        await fulfillAllPastRequestsIds(mocked);
      }
    }
  }
};
