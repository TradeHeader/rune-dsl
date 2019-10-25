/*

 * generated by Xtext 2.10.0
 */
package com.regnosys.rosetta.generator

import com.google.inject.Inject
import com.regnosys.rosetta.RosettaExtensions
import com.regnosys.rosetta.generator.external.ExternalGenerators
import com.regnosys.rosetta.generator.java.blueprints.BlueprintGenerator
import com.regnosys.rosetta.generator.java.enums.EnumGenerator
import com.regnosys.rosetta.generator.java.function.FuncGenerator
import com.regnosys.rosetta.generator.java.object.DataGenerator
import com.regnosys.rosetta.generator.java.object.DataValidatorsGenerator
import com.regnosys.rosetta.generator.java.object.MetaFieldGenerator
import com.regnosys.rosetta.generator.java.object.ModelMetaGenerator
import com.regnosys.rosetta.generator.java.object.ModelObjectGenerator
import com.regnosys.rosetta.generator.java.qualify.QualifyFunctionGenerator
import com.regnosys.rosetta.generator.java.rule.ChoiceRuleGenerator
import com.regnosys.rosetta.generator.java.rule.DataRuleGenerator
import com.regnosys.rosetta.generator.java.util.JavaNames
import com.regnosys.rosetta.generator.util.RosettaFunctionExtensions
import com.regnosys.rosetta.rosetta.RosettaClass
import com.regnosys.rosetta.rosetta.RosettaEvent
import com.regnosys.rosetta.rosetta.RosettaMetaType
import com.regnosys.rosetta.rosetta.RosettaModel
import com.regnosys.rosetta.rosetta.RosettaProduct
import com.regnosys.rosetta.rosetta.simple.Data
import com.regnosys.rosetta.rosetta.simple.Function
import com.rosetta.util.DemandableLock
import org.apache.log4j.Level
import org.apache.log4j.Logger
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.AbstractGenerator
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext

/**
 * Generates code from your model files on save.
 * 
 * See https://www.eclipse.org/Xtext/documentation/303_runtime_concepts.html#code-generation
 */
class RosettaGenerator extends AbstractGenerator {
	static Logger LOGGER = Logger.getLogger(RosettaGenerator) =>[level = Level.DEBUG]

	@Inject ModelObjectGenerator modelObjectGenerator
	@Inject EnumGenerator enumGenerator
	@Inject ModelMetaGenerator metaGenerator
	@Inject ChoiceRuleGenerator choiceRuleGenerator
	@Inject DataRuleGenerator dataRuleGenerator
	@Inject BlueprintGenerator blueprintGenerator
	@Inject QualifyFunctionGenerator<RosettaEvent> qualifyEventsGenerator
	@Inject QualifyFunctionGenerator<RosettaProduct> qualifyProductsGenerator
	@Inject MetaFieldGenerator metaFieldGenerator
	@Inject ExternalGenerators externalGenerators
	
	@Inject DataGenerator dataGenerator
	@Inject DataValidatorsGenerator validatorsGenerator
	@Inject extension RosettaFunctionExtensions
	@Inject extension RosettaExtensions
	@Inject JavaNames.Factory factory
	@Inject FuncGenerator funcGenerator
	
	// For files that are
	val ignoredFiles = #{'model-no-code-gen.rosetta'}
	
	val lock = new DemandableLock;

	override void doGenerate(Resource resource, IFileSystemAccess2 fsa, IGeneratorContext context) {
		LOGGER.debug("Starting the main generate method for "+resource.URI.toString)  
		try {
			lock.getWriteLock(true);
		if (!ignoredFiles.contains(resource.URI.segments.last)) {	
			// generate for each model object
			resource.contents.filter(RosettaModel).forEach [
				val version = header.version
				val javaNames = factory.create(it)
				val packages = javaNames.packages
				
				elements.forEach [
					switch(it) {
						Data: {
							dataGenerator.generate(javaNames, fsa, it, version)
							metaGenerator.generate(javaNames, fsa, it, version)
							validatorsGenerator.generate(javaNames, fsa, it, version)
							it.conditions.forEach [ cond |
								if (cond.isChoiceRuleCondition) {
									choiceRuleGenerator.generate(javaNames, fsa, it, cond, version)
								} else {
									dataRuleGenerator.generate(javaNames, fsa, it, cond, version)
								}
							]
						}
						Function:{
							if(!isDispatchingFunction){
								funcGenerator.generate(javaNames, fsa, it, version)
							}
						}
					}
				]
				modelObjectGenerator.generate(javaNames, fsa, elements, version)
				enumGenerator.generate(packages, fsa, elements, version)
				choiceRuleGenerator.generate(packages, fsa, elements, version)
				dataRuleGenerator.generate(javaNames, fsa, elements, version)
				metaGenerator.generate(packages, fsa, elements, version)
				blueprintGenerator.generate(packages, fsa, elements, version)
				qualifyEventsGenerator.generate(packages, fsa, elements, packages.qualifyEvent, RosettaEvent, version)
				qualifyProductsGenerator.generate(packages, fsa, elements, packages.qualifyProduct, RosettaProduct, version)
				
				// Invoke externally defined code generators
				externalGenerators.forEach[generator |
					generator.generate(packages, elements, version,[map|
						map.entrySet.forEach[fsa.generateFile(key, generator.outputConfiguration.getName, value)]],resource, lock)
				]
			]
			
			val models = resource.resourceSet.resources.flatMap[contents].filter(RosettaModel).toList
			val allElements = models.flatMap[elements].toList

			val classes = resource.contents.filter(RosettaModel).head.elements.filter[it instanceof RosettaClass || it instanceof Data]
			metaFieldGenerator.generate(fsa, allElements.filter(RosettaMetaType), classes, models.map[header].filter(a|a!==null).map[namespace].toSet)
		}}
		catch (Exception e) {
			LOGGER.warn("Unexpected calling standard generate for rosetta -"+e.message+" - see debug logging for more")
			LOGGER.info("Unexpected calling standard generate for rosetta", e);
		}
		finally {
			LOGGER.debug("ending the main generate method")
			lock.releaseWriteLock
		}
	}

	override void afterGenerate(Resource resource, IFileSystemAccess2 fsa, IGeneratorContext context) {
		try {
			val models = resource.resourceSet.resources.flatMap[contents].filter(RosettaModel).toList
			
			
			externalGenerators.forEach[generator |
					generator.afterGenerate(models,[map|
						map.entrySet.forEach[fsa.generateFile(key, generator.outputConfiguration.getName, value)]],resource, lock)
				]
		
		} catch (Exception e) {
			LOGGER.warn("Unexpected calling after generate for rosetta -"+e.message+" - see debug logging for more")
			LOGGER.debug("Unexpected calling after generate for rosetta", e);
		}

	}

}
