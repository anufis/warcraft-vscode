/**
 * @File   : debug.ts
 * @Author : Dencer (tdaddon@163.com)
 * @Link   : https://dengsir.github.io
 * @Date   : 5/23/2019, 12:27:34 PM
 */

import * as path from 'path';
import * as fs from 'fs-extra';
import * as utils from '../../utils';

import { env } from '../../env';
import { globals, localize } from '../../globals';

import { Packer, PackerType } from './packer';

type PackItem = [string, string];

export class DebugPacker implements Packer {
    type() {
        return PackerType.Debug;
    }

    async generatePackList() {
        const packList = [
            ...(await this.generatePackItems(
                env.mapFolder,
                file => !utils.isLuaFile(file) && !utils.isHiddenFile(file)
            )),
            ...(await this.generatePackItems(env.importsFolder, file => !utils.isHiddenFile(file))),
            [globals.ENTRY_FILE, env.asBuildPath(globals.ENTRY_FILE)]
        ];

        const libs = await utils.getAllFiles(env.asSourceFolder('lib'), true, false);
        for (const lib of libs) {
            const imp = path.join(lib, env.importsDirName);
            if (await fs.pathExists(imp)) {
                packList.push(...(await this.generatePackItems(imp, file => !utils.isHiddenFile(file))));
            }
        }

        await fs.writeFile(env.asBuildPath(globals.PACKLIST_FILE), JSON.stringify(packList));
    }

    async packByPackList() {
        await utils.execFile(env.asExetensionPath('bin/MopaqPack.exe'), [
            '-o',
            env.asBuildPath(globals.DEBUG_MAP_FILE),
            env.asBuildPath(globals.PACKLIST_FILE)
        ]);
    }

    @utils.report(localize('report.pack', 'Packing map'))
    async execute() {
        await this.generatePackList();
        await this.packByPackList();
    }

    private async generatePackItems(root: string, filter?: (file: string) => boolean) {
        if (!(await fs.pathExists(root)) || !(await fs.stat(root)).isDirectory()) {
            return [];
        }
        let files = await utils.getAllFiles(root);
        if (filter) {
            files = files.filter(filter);
        }
        return files.map(file => this.generatePackItem(file, root));
    }

    private generatePackItem(file: string, root: string): PackItem {
        return [path.relative(root, file), file];
    }
}

export const debugPacker = new DebugPacker();
