//
//  KotlinObjectBridgeTests.kt
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

package com.o2ter.jscore

import com.o2ter.jscore.jvm.JvmPlatformContext
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import kotlin.test.assertNotNull

// Test data classes and classes with member functions
data class Person(
    val name: String,
    val age: Int
) {
    fun getInfo(): String = "Name: $name, Age: $age"
    fun isAdult(): Boolean = age >= 18
    fun greet(greeting: String): String = "$greeting, I'm $name"
}

class Calculator {
    private var internalResult: Double = 0.0
    
    fun add(a: Double, b: Double): Double {
        internalResult = a + b
        return internalResult
    }
    
    fun multiply(a: Double, b: Double): Double {
        internalResult = a * b
        return internalResult
    }
    
    fun getResult(): Double = internalResult
}

class Counter {
    private var count: Int = 0
    
    fun increment(): Int {
        count++
        return count
    }
    
    fun decrement(): Int {
        count--
        return count
    }
    
    fun reset(): Int {
        count = 0
        return count
    }
    
    fun getValue(): Int = count
}

class StringProcessor {
    fun toUpperCase(text: String): String = text.uppercase()
    fun toLowerCase(text: String): String = text.lowercase()
    fun reverse(text: String): String = text.reversed()
    fun repeat(text: String, times: Int): String = text.repeat(times)
}

// Class with mutable properties for testing set trap
class MutableConfig {
    var name: String = "default"
    var timeout: Int = 30
    val readOnly: String = "immutable"
    
    fun getName(): String = name
    fun getTimeout(): Int = timeout
}

class KotlinObjectBridgeTests {

    @Test
    fun testDataClassPropertyAccess() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val person = Person("Alice", 30)
            
            val result = engine.execute(
                mapOf("person" to person),
                """
                ({
                    name: person.name,
                    age: person.age
                })
                """
            )
            
            assertTrue(result is Map<*, *>)
            val map = result as Map<*, *>
            assertEquals("Alice", map["name"])
            assertEquals(30, map["age"])
        }
    }

    @Test
    fun testDataClassMethodCall() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val person = Person("Bob", 25)
            
            val result = engine.execute(
                mapOf("person" to person),
                """
                ({
                    info: person.getInfo(),
                    isAdult: person.isAdult()
                })
                """
            )
            
            assertTrue(result is Map<*, *>)
            val map = result as Map<*, *>
            assertEquals("Name: Bob, Age: 25", map["info"])
            assertEquals(true, map["isAdult"])
        }
    }

    @Test
    fun testMethodWithArguments() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val person = Person("Charlie", 17)
            
            val result = engine.execute(
                mapOf("person" to person),
                """
                ({
                    greeting1: person.greet('Hello'),
                    greeting2: person.greet('Hi'),
                    isAdult: person.isAdult()
                })
                """
            )
            
            assertTrue(result is Map<*, *>)
            val map = result as Map<*, *>
            assertEquals("Hello, I'm Charlie", map["greeting1"])
            assertEquals("Hi, I'm Charlie", map["greeting2"])
            assertEquals(false, map["isAdult"])
        }
    }

    @Test
    fun testStatefulClassMethods() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val calculator = Calculator()
            
            val result = engine.execute(
                mapOf("calc" to calculator),
                """
                ({
                    sum: calc.add(10, 5),
                    product: calc.multiply(3, 4),
                    finalResult: calc.getResult()
                })
                """
            )
            
            assertTrue(result is Map<*, *>)
            val map = result as Map<*, *>
            // V8 stores whole numbers as integers, so 15.0 becomes 15
            assertEquals(15, map["sum"])
            assertEquals(12, map["product"])
            assertEquals(12, map["finalResult"])
        }
    }

    @Test
    fun testCounterStateChanges() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val counter = Counter()
            
            val result = engine.execute(
                mapOf("counter" to counter),
                """
                ({
                    initial: counter.getValue(),
                    afterInc1: counter.increment(),
                    afterInc2: counter.increment(),
                    afterInc3: counter.increment(),
                    afterDec: counter.decrement(),
                    afterReset: counter.reset(),
                    final: counter.getValue()
                })
                """
            )
            
            assertTrue(result is Map<*, *>)
            val map = result as Map<*, *>
            assertEquals(0, map["initial"])
            assertEquals(1, map["afterInc1"])
            assertEquals(2, map["afterInc2"])
            assertEquals(3, map["afterInc3"])
            assertEquals(2, map["afterDec"])
            assertEquals(0, map["afterReset"])
            assertEquals(0, map["final"])
        }
    }

    @Test
    fun testStringProcessorMethods() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val processor = StringProcessor()
            
            val result = engine.execute(
                mapOf("processor" to processor),
                """
                ({
                    upper: processor.toUpperCase('hello'),
                    lower: processor.toLowerCase('WORLD'),
                    reversed: processor.reverse('kotlin'),
                    repeated: processor.repeat('ha', 3)
                })
                """
            )
            
            assertTrue(result is Map<*, *>)
            val map = result as Map<*, *>
            assertEquals("HELLO", map["upper"])
            assertEquals("world", map["lower"])
            assertEquals("niltok", map["reversed"])
            assertEquals("hahaha", map["repeated"])
        }
    }

    @Test
    fun testMultipleObjectsWithMethods() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val person1 = Person("Alice", 30)
            val person2 = Person("Bob", 25)
            
            val result = engine.execute(
                mapOf(
                    "person1" to person1,
                    "person2" to person2
                ),
                """
                ({
                    info1: person1.getInfo(),
                    info2: person2.getInfo(),
                    greet1: person1.greet('Hi'),
                    greet2: person2.greet('Hello'),
                    bothAdults: person1.isAdult() && person2.isAdult()
                })
                """
            )
            
            assertTrue(result is Map<*, *>)
            val map = result as Map<*, *>
            assertEquals("Name: Alice, Age: 30", map["info1"])
            assertEquals("Name: Bob, Age: 25", map["info2"])
            assertEquals("Hi, I'm Alice", map["greet1"])
            assertEquals("Hello, I'm Bob", map["greet2"])
            assertEquals(true, map["bothAdults"])
        }
    }

    @Test
    fun testMethodChaining() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val processor = StringProcessor()
            
            val result = engine.execute(
                mapOf("processor" to processor),
                """
                ({
                    result: processor.toUpperCase(processor.reverse('hello'))
                })
                """
            )
            
            assertTrue(result is Map<*, *>)
            val map = result as Map<*, *>
            assertEquals("OLLEH", map["result"])
        }
    }

    @Test
    fun testObjectInArray() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val people = listOf(
                Person("Alice", 30),
                Person("Bob", 17),
                Person("Charlie", 25)
            )
            
            val result = engine.execute(
                mapOf("people" to people),
                """
                ({
                    infos: people.map(p => p.getInfo()),
                    adults: people.filter(p => p.isAdult()).map(p => p.name),
                    greetings: people.map(p => p.greet('Hello'))
                })
                """
            )
            
            assertTrue(result is Map<*, *>)
            val map = result as Map<*, *>
            
            assertEquals(
                listOf("Name: Alice, Age: 30", "Name: Bob, Age: 17", "Name: Charlie, Age: 25"),
                map["infos"]
            )
            assertEquals(listOf("Alice", "Charlie"), map["adults"])
            assertEquals(
                listOf("Hello, I'm Alice", "Hello, I'm Bob", "Hello, I'm Charlie"),
                map["greetings"]
            )
        }
    }

    @Test
    fun testObjectPropertyEnumeration() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val person = Person("Alice", 30)
            
            val result = engine.execute(
                mapOf("person" to person),
                """
                ({
                    keys: Object.keys(person),
                    hasName: 'name' in person,
                    hasAge: 'age' in person,
                    hasGetInfo: 'getInfo' in person,
                    hasIsAdult: 'isAdult' in person
                })
                """
            )
            
            assertTrue(result is Map<*, *>)
            val map = result as Map<*, *>
            
            val keys = map["keys"] as? List<*>
            assertNotNull(keys)
            assertTrue(keys.contains("name"))
            assertTrue(keys.contains("age"))
            
            assertEquals(true, map["hasName"])
            assertEquals(true, map["hasAge"])
            assertEquals(true, map["hasGetInfo"])
            assertEquals(true, map["hasIsAdult"])
        }
    }

    @Test
    fun testNestedObjectMethodCalls() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val data = mapOf(
                "person" to Person("Alice", 30),
                "counter" to Counter()
            )
            
            val result = engine.execute(
                mapOf("data" to data),
                """
                ({
                    personInfo: data.person.getInfo(),
                    counterStart: data.counter.getValue(),
                    counterAfterInc: data.counter.increment(),
                    personAdult: data.person.isAdult()
                })
                """
            )
            
            assertTrue(result is Map<*, *>)
            val map = result as Map<*, *>
            assertEquals("Name: Alice, Age: 30", map["personInfo"])
            assertEquals(0, map["counterStart"])
            assertEquals(1, map["counterAfterInc"])
            assertEquals(true, map["personAdult"])
        }
    }

    @Test
    fun testMutablePropertySet() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val config = MutableConfig()
            
            val result = engine.execute(
                mapOf("config" to config),
                """
                ({
                    originalName: config.name,
                    originalTimeout: config.timeout,
                    setNameResult: (function() {
                        config.name = "updated";
                        return true;
                    })(),
                    newName: config.name,
                    setTimeoutResult: (function() {
                        config.timeout = 60;
                        return true;
                    })(),
                    newTimeout: config.timeout,
                    getNameMethod: config.getName(),
                    getTimeoutMethod: config.getTimeout()
                })
                """
            )
            
            assertTrue(result is Map<*, *>)
            val map = result as Map<*, *>
            assertEquals("default", map["originalName"])
            assertEquals(30, map["originalTimeout"])
            assertEquals(true, map["setNameResult"])
            assertEquals("updated", map["newName"])
            assertEquals(true, map["setTimeoutResult"])
            assertEquals(60, map["newTimeout"])
            assertEquals("updated", map["getNameMethod"])
            assertEquals(60, map["getTimeoutMethod"])
            
            // Verify the actual Kotlin object was modified
            assertEquals("updated", config.name)
            assertEquals(60, config.timeout)
        }
    }

    @Test
    fun testImmutablePropertySet() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val config = MutableConfig()
            
            val result = engine.execute(
                mapOf("config" to config),
                """
                ({
                    originalValue: config.readOnly,
                    setResult: (function() {
                        try {
                            config.readOnly = "modified";
                            return true;
                        } catch (e) {
                            return false;
                        }
                    })(),
                    finalValue: config.readOnly
                })
                """
            )
            
            assertTrue(result is Map<*, *>)
            val map = result as Map<*, *>
            assertEquals("immutable", map["originalValue"])
            assertEquals(false, map["setResult"]) // Setting should fail
            assertEquals("immutable", map["finalValue"]) // Value should be unchanged
        }
    }

    @Test
    fun testDeleteProperty() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val person = Person("Bob", 25)
            
            val result = engine.execute(
                mapOf("person" to person),
                """
                ({
                    hasNameBefore: 'name' in person,
                    deleteResult: delete person.name,
                    hasNameAfter: 'name' in person,
                    nameValue: person.name
                })
                """
            )
            
            assertTrue(result is Map<*, *>)
            val map = result as Map<*, *>
            assertEquals(true, map["hasNameBefore"])
            assertEquals(false, map["deleteResult"]) // Delete should fail
            assertEquals(true, map["hasNameAfter"]) // Property should still exist
            assertEquals("Bob", map["nameValue"]) // Value should be unchanged
        }
    }

    @Test
    fun testPropertyWritableDescriptor() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val config = MutableConfig()
            
            val result = engine.execute(
                mapOf("config" to config),
                """
                ({
                    nameDescriptor: Object.getOwnPropertyDescriptor(config, 'name'),
                    readOnlyDescriptor: Object.getOwnPropertyDescriptor(config, 'readOnly'),
                    methodDescriptor: Object.getOwnPropertyDescriptor(config, 'getName')
                })
                """
            )
            
            assertTrue(result is Map<*, *>)
            val map = result as Map<*, *>
            
            val nameDesc = map["nameDescriptor"] as? Map<*, *>
            assertNotNull(nameDesc)
            assertEquals(true, nameDesc["writable"]) // Mutable property is writable
            assertEquals(true, nameDesc["enumerable"])
            assertEquals(true, nameDesc["configurable"])
            
            val readOnlyDesc = map["readOnlyDescriptor"] as? Map<*, *>
            assertNotNull(readOnlyDesc)
            assertEquals(false, readOnlyDesc["writable"]) // Immutable property is not writable
            assertEquals(true, readOnlyDesc["enumerable"])
            assertEquals(true, readOnlyDesc["configurable"])
            
            val methodDesc = map["methodDescriptor"] as? Map<*, *>
            assertNotNull(methodDesc)
            assertEquals(false, methodDesc["writable"]) // Methods are not writable
            assertEquals(true, methodDesc["enumerable"])
            assertEquals(true, methodDesc["configurable"])
        }
    }
}
