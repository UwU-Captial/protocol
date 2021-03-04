import { ethers } from 'hardhat';

import SeedFactoryArtifact from '../artifacts/contracts/Seed.sol/Seed.json';
import IUniswapV2PairArtifact from '../artifacts/@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol/IUniswapV2Pair.json';
import ERC20Artifact from '../artifacts/@openzeppelin/contracts/token/ERC20/ERC20.sol/ERC20.json';
import { SeedFactory } from '../type/SeedFactory';
import { Erc20 } from '../type/Erc20';
import { IUniswapV2Pair } from '../type/IUniswapV2Pair';

import { formatEther, parseEther, parseUnits } from 'ethers/lib/utils';
import { promises } from 'fs';

async function main() {
	const signer = await ethers.getSigners();
	const account = await signer[0].getAddress();

	try {
		let data = await promises.readFile('contracts.json', 'utf-8');
		let dataParse = JSON.parse(data.toString());

		const uwu = ((await ethers.getContractAt(ERC20Artifact.abi, dataParse['uwu'], signer[0])) as any) as Erc20;
		const bnb = ((await ethers.getContractAt(ERC20Artifact.abi, dataParse['bnb'], signer[0])) as any) as Erc20;
		const busd = ((await ethers.getContractAt(ERC20Artifact.abi, dataParse['busd'], signer[0])) as any) as Erc20;

		const uwuDistribution = parseEther('20000');
		const seedCap = parseEther('1000000');
		const walletCapPercentage = 5;
		const scale = parseEther('1');
		const seedDuration = 60 * 60 * 5;
		const distributionTime = 60 * 60 * 10;

		const uniswapV2Pair = new ethers.Contract(
			'0xcb809551f296841da073f997911cc461c77ae142',
			IUniswapV2PairArtifact.abi,
			signer[0]
		) as IUniswapV2Pair;
		const resData = await uniswapV2Pair.getReserves();

		const factory = '0xd417A0A4b65D24f5eBD0898d9028D92E3592afCC';
		const router = '0x07d090e7fcbc6afaa507a3441c7c5ee507c457e6';

		const currentPrice = resData.reserve0.mul(scale).div(resData.reserve1);
		const bnbCap = seedCap.mul(scale).div(currentPrice);
		const walletCap = bnbCap.mul(walletCapPercentage).div(100);
		const tokenExchangeRate = uwuDistribution.mul(scale).div(bnbCap);

		console.log(
			formatEther(currentPrice),
			formatEther(bnbCap),
			formatEther(walletCap),
			formatEther(tokenExchangeRate)
		);

		const seedFactory = (new ethers.ContractFactory(
			SeedFactoryArtifact.abi,
			SeedFactoryArtifact.bytecode,
			signer[0]
		) as any) as SeedFactory;

		const seed = await seedFactory.deploy(
			uwu.address,
			bnb.address,
			busd.address,
			factory,
			router,
			account,
			bnbCap,
			walletCap,
			currentPrice,
			tokenExchangeRate,
			uwuDistribution,
			seedDuration,
			distributionTime
		);

		dataParse['seed'] = seed.address;
		const updateData = JSON.stringify(dataParse);
		await promises.writeFile('contracts.json', updateData);
	} catch (error) {
		console.error(error);
	}
}

main().then(() => process.exit(0)).catch((error) => {
	console.error(error);
	process.exit(1);
});
