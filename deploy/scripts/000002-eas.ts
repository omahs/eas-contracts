import { deploy, DeployedContracts, InstanceName, setDeploymentMetadata } from '../../utils/Deploy';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

const func: DeployFunction = async ({ getNamedAccounts }: HardhatRuntimeEnvironment) => {
  const { deployer } = await getNamedAccounts();

  const registry = await DeployedContracts.SchemaRegistry.deployed();

  await deploy({ name: InstanceName.EAS, from: deployer, args: [registry.address] });

  return true;
};

export default setDeploymentMetadata(__filename, func);
