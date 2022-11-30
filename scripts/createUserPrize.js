const { ethers } = require("hardhat")
const fs = require('fs');

const privateKey = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";

// 对要签名的参数进行编码
function getMessageBytes(campaignAddress, account, amount) {
    // console.log(account);
    // console.log(amount);

    // 对应solidity的Keccak256
    const messageHash = ethers.utils.solidityKeccak256(["address", "address", "uint256"], [campaignAddress, account, amount])
    console.log("Message Hash: ", messageHash)
    // 由于 ethers 库的要求，需要先对哈希值数组化
    const messageBytes = ethers.utils.arrayify(messageHash)
    console.log("messageBytes: ", messageBytes)
    // 返回数组化的hash
    return messageBytes
}

// 返回签名
async function getSignature(signer, campaignAddress, account, amount) {
    const messageBytes = getMessageBytes(campaignAddress, account, amount)
    // 对数组化hash进行签名，自动添加"\x19Ethereum Signed Message:\n32"并进行签名
    const signature = await signer.signMessage(messageBytes)
    console.log("Signature: ", signature);
    let { r, s, v } = ethers.utils.splitSignature(signature)
    return {r,s,v};
}

async function main() {
    const signer = new ethers.Wallet(privateKey);
    let campaignAddress = '0xa16E02E87b7454126E5E10d957A927A7F5B5d2be';
    let user_addresses = [
        '0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199',
        '0xdD2FD4581271e230360230F9337D5c0430Bf44C0',
        '0xbDA5747bFD65F08deb54cb465eB87D40e51B197E',
        '0x2546BcD3c84621e976D8185a91A922aE77ECEc30'
    ];


    let output = [];
    // 我们将accounts[0]作为deployer和signer，account[1]、account[2]、account[3]作为白名单地址
    for (let i = 0; i < user_addresses.length; i++) {
        let signature = await getSignature(signer, campaignAddress, user_addresses[i], 10);
        console.log('Generating...');
        output.push({
            wallet: user_addresses[i],
            r: signature.r,
            s: signature.s,
            v: signature.v
        })
    }

    // Save the generated coupons to a coupons.json file
    let data = JSON.stringify(output);
    fs.writeFileSync('./resource/coupons.json', data);
    console.log('Done.');
    console.log('Please Check the coupons.json file.');

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })

