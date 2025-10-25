//
//  ProcessEnvTests.kt
//
//  The MIT License
//  Copyright (c) 2021 - 2025 O2ter Limited. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

package com.o2ter.jscore.polyfill

import com.o2ter.jscore.JavaScriptEngine
import com.o2ter.jscore.jvm.JvmPlatformContext
import org.junit.After
import org.junit.Before
import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class ProcessEnvTests {

    @Test
    fun testProcessEnvNodeJsBehavior() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val script = """
            // Assignment converts to string
            process.env.TEST_VAR = 123;
            if (process.env.TEST_VAR !== '123') throw new Error('Assignment converts number to string');
            process.env.TEST_VAR = null;
            if (process.env.TEST_VAR !== 'null') throw new Error('Assignment converts null to string');
            process.env.TEST_VAR = undefined;
            if (process.env.TEST_VAR !== 'undefined') throw new Error('Assignment converts undefined to string');
            process.env.TEST_VAR = 'abc';
            if (process.env.TEST_VAR !== 'abc') throw new Error('Assignment keeps string');

            // Deletion
            process.env.DELETE_ME = 'bye';
            if (process.env.DELETE_ME !== 'bye') throw new Error('Set value before delete');
            delete process.env.DELETE_ME;
            if (process.env.DELETE_ME !== undefined) throw new Error('Delete property');

            // Object.keys
            process.env.KEYS1 = 'a';
            process.env.KEYS2 = 'b';
            const keys = Object.keys(process.env);
            if (!(keys.includes('KEYS1') && keys.includes('KEYS2'))) throw new Error('Object.keys includes set keys');

            // Object.getOwnPropertyNames
            const props = Object.getOwnPropertyNames(process.env);
            if (!(props.includes('KEYS1') && props.includes('KEYS2'))) throw new Error('Object.getOwnPropertyNames includes set keys');

            // Object.assign
            const assigned = Object.assign({}, process.env);
            if (assigned.KEYS1 !== 'a') throw new Error('Object.assign copies env property');

            // for...in
            let found = false;
            for (const k in process.env) {
                if (k === 'KEYS1') found = true;
            }
            if (!found) throw new Error('for...in enumerates env keys');

            // hasOwnProperty
            if (!Object.prototype.hasOwnProperty.call(process.env, 'KEYS1')) throw new Error('hasOwnProperty works');

            // property descriptor
            const desc = Object.getOwnPropertyDescriptor(process.env, 'KEYS1');
            if (!(desc && desc.enumerable && desc.configurable)) throw new Error('Property descriptor is correct');

            // delete non-existent
            let deleteResult = true;
            try {
                deleteResult = delete process.env.NOT_EXIST;
            } catch (e) {
                deleteResult = false;
            }
            if (!deleteResult) throw new Error('Delete non-existent property returns true');

            // Overwrite value
            process.env.KEYS1 = 42;
            if (process.env.KEYS1 !== '42') throw new Error('Overwrite value converts to string');

            // Symbol keys are ignored
            const sym = Symbol('foo');
            process.env[sym] = 'bar';
            if (process.env[sym] !== undefined) throw new Error('Symbol keys are ignored');

            // JSON.stringify
            const json = JSON.stringify(process.env);
            if (!(json.includes('KEYS1') && json.includes('KEYS2'))) throw new Error('JSON.stringify includes env keys');

            // Object.entries
            const entries = Object.entries(process.env);
            if (!entries.some(([k, v]) => k === 'KEYS1' && v === '42')) throw new Error('Object.entries works');

            // Object.values
            const values = Object.values(process.env);
            if (!(values.includes('42') && values.includes('b'))) throw new Error('Object.values works');

            // Reflect.ownKeys
            const ownKeys = Reflect.ownKeys(process.env);
            if (!(ownKeys.includes('KEYS1') && ownKeys.includes('KEYS2'))) throw new Error('Reflect.ownKeys works');

            // in operator
            if (!('KEYS1' in process.env)) throw new Error('in operator works');

            // Clear test keys
            delete process.env.KEYS1;
            delete process.env.KEYS2;
            'ok';
        """
        val result = engine.execute(script)
        assertEquals("ok", result?.toString())
    }
}
