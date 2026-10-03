import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'main.dart';
import 'ats_cv_builder_screen.dart';

// Data models for multiple entries
class WorkExperience {
  final TextEditingController jobTitleController = TextEditingController();
  final TextEditingController companyController = TextEditingController();
  final TextEditingController durationController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'jobTitle': jobTitleController.text,
      'company': companyController.text,
      'duration': durationController.text,
      'description': descriptionController.text,
    };
  }

  // Create from JSON
  static WorkExperience fromJson(Map<String, dynamic> json) {
    final exp = WorkExperience();
    exp.jobTitleController.text = json['jobTitle'] ?? '';
    exp.companyController.text = json['company'] ?? '';
    exp.durationController.text = json['duration'] ?? '';
    exp.descriptionController.text = json['description'] ?? '';
    return exp;
  }

  void dispose() {
    jobTitleController.dispose();
    companyController.dispose();
    durationController.dispose();
    descriptionController.dispose();
  }
}

class Education {
  final TextEditingController degreeController = TextEditingController();
  final TextEditingController schoolController = TextEditingController();
  final TextEditingController graduationController = TextEditingController();

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'degree': degreeController.text,
      'school': schoolController.text,
      'graduation': graduationController.text,
    };
  }

  // Create from JSON
  static Education fromJson(Map<String, dynamic> json) {
    final edu = Education();
    edu.degreeController.text = json['degree'] ?? '';
    edu.schoolController.text = json['school'] ?? '';
    edu.graduationController.text = json['graduation'] ?? '';
    return edu;
  }

  void dispose() {
    degreeController.dispose();
    schoolController.dispose();
    graduationController.dispose();
  }
}

class ResumeBuilderScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  
  const ResumeBuilderScreen({super.key, required this.cameras});

  @override
  State<ResumeBuilderScreen> createState() => _ResumeBuilderScreenState();
}

class _ResumeBuilderScreenState extends State<ResumeBuilderScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  
  // Form controllers
  final _personalFormKey = GlobalKey<FormState>();
  final _experienceFormKey = GlobalKey<FormState>();
  final _educationFormKey = GlobalKey<FormState>();
  final _skillsFormKey = GlobalKey<FormState>();
  
  // Personal Information
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  
  // Multiple Work Experiences
  List<WorkExperience> _workExperiences = [WorkExperience()];
  
  // Multiple Education Entries
  List<Education> _educations = [Education()];
  
  // Skills
  final TextEditingController _skillsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedResume();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _summaryController.dispose();
    _skillsController.dispose();
    
    // Dispose work experiences
    for (var experience in _workExperiences) {
      experience.dispose();
    }
    
    // Dispose educations
    for (var education in _educations) {
      education.dispose();
    }
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BauhausColors.lightGray,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            
            // Progress indicator
            _buildProgressIndicator(),
            
            // Content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentStep = index;
                  });
                },
                children: [
                  _buildPersonalInfoStep(),
                  _buildExperienceStep(),
                  _buildEducationStep(),
                  _buildSkillsStep(),
                  _buildPreviewStep(),
                ],
              ),
            ),
            
            // Navigation buttons
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 160,
      color: BauhausColors.blue, //BauhausColors.blue, // Green color for resume builder
      child: Stack(
        children: [
          // Yellow circle accent
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: BauhausColors.yellow,
                shape: BoxShape.circle,
              ),
            ),
          ),
          
          // Red rectangle accent
          Positioned(
            bottom: 15,
            left: 15,
            child: Container(
              width: 60,
              height: 25,
              color: BauhausColors.red,
            ),
          ),
          
          // Back button
          Positioned(
            top: 15,
            left: 15,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: BauhausColors.white,
                  border: Border.all(
                    color: BauhausColors.black,
                    width: 3,
                  ),
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: BauhausColors.black,
                  size: 20,
                ),
              ),
            ),
          ),
          
          // Title
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'RESUME',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: BauhausColors.white,
                    letterSpacing: 6,
                    height: 0.9,
                  ),
                ),
                Text(
                  'BUILDER',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: BauhausColors.yellow,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 50,
                  height: 2,
                  color: BauhausColors.white,
                ),
              ],
            ),
          ),
          
          // Save Draft & Load buttons
          Positioned(
            top: 15,
            right: 15,
            child: Row(
              children: [
                // Load existing resume button
                GestureDetector(
                  onTap: _showLoadOptions,
                  child: Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: BauhausColors.yellow,
                      border: Border.all(
                        color: BauhausColors.black,
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      Icons.folder_open,
                      color: BauhausColors.black,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Save draft button
                GestureDetector(
                  onTap: _saveResumeData,
                  child: Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: BauhausColors.white,
                      border: Border.all(
                        color: BauhausColors.black,
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      Icons.save,
                      color: BauhausColors.black,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: BauhausColors.white,
      child: Row(
        children: List.generate(5, (index) {
          final isActive = index <= _currentStep;
          final isCompleted = index < _currentStep;
          
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < 4 ? 10 : 0),
              child: Column(
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive 
                          ? BauhausColors.blue
                          : BauhausColors.lightGray,
                      border: Border.all(
                        color: BauhausColors.black,
                        width: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    ['PERSONAL', 'EXPERIENCE', 'EDUCATION', 'SKILLS', 'PREVIEW'][index],
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: isActive 
                          ? BauhausColors.black 
                          : BauhausColors.gray,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPersonalInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _personalFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('PERSONAL INFO', Icons.person),
            const SizedBox(height: 25),
            
            _buildTextField(
              controller: _nameController,
              label: 'FULL NAME',
              hint: 'Enter your full name',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 20),
            
            _buildTextField(
              controller: _emailController,
              label: 'EMAIL ADDRESS',
              hint: 'your.email@example.com',
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Email is required';
                }
                if (!value.contains('@')) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 20),
            
            _buildTextField(
              controller: _phoneController,
              label: 'PHONE NUMBER',
              hint: '+1 (555) 123-4567',
              keyboardType: TextInputType.phone,
            ),
            
            const SizedBox(height: 20),
            
            _buildTextField(
              controller: _locationController,
              label: 'LOCATION',
              hint: 'City, State/Country',
            ),
            
            const SizedBox(height: 20),
            
            _buildTextField(
              controller: _summaryController,
              label: 'PROFESSIONAL SUMMARY',
              hint: 'Brief summary of your professional background...',
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExperienceStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _experienceFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('WORK EXPERIENCE', Icons.work),
            const SizedBox(height: 25),
            
            // List of work experiences
            ...List.generate(_workExperiences.length, (index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 25),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: BauhausColors.white,
                  border: Border.all(color: BauhausColors.black, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with experience number and delete button
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: BauhausColors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: BauhausColors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'WORK EXPERIENCE ${index + 1}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: BauhausColors.black,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        if (_workExperiences.length > 1)
                          GestureDetector(
                            onTap: () => _removeWorkExperience(index),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: BauhausColors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.delete,
                                color: BauhausColors.white,
                                size: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    _buildTextField(
                      controller: _workExperiences[index].jobTitleController,
                      label: 'JOB TITLE',
                      hint: 'Software Engineer, Marketing Manager, etc.',
                      validator: (value) {
                        if (index == 0 && (value == null || value.isEmpty)) {
                          return 'First job title is required';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 15),
                    
                    _buildTextField(
                      controller: _workExperiences[index].companyController,
                      label: 'COMPANY NAME',
                      hint: 'Company/Organization name',
                      validator: (value) {
                        if (index == 0 && (value == null || value.isEmpty)) {
                          return 'First company name is required';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 15),
                    
                    _buildTextField(
                      controller: _workExperiences[index].durationController,
                      label: 'DURATION',
                      hint: 'Jan 2020 - Present',
                    ),
                    
                    const SizedBox(height: 15),
                    
                    _buildTextField(
                      controller: _workExperiences[index].descriptionController,
                      label: 'JOB DESCRIPTION',
                      hint: 'Describe your key responsibilities and achievements...',
                      maxLines: 4,
                    ),
                  ],
                ),
              );
            }),
            
            // Add more experience button
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: BauhausColors.lightGray,
                border: Border.all(color: BauhausColors.black, width: 2),
              ),
              child: MaterialButton(
                onPressed: _addWorkExperience,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add,
                      color: BauhausColors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ADD ANOTHER EXPERIENCE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: BauhausColors.blue,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEducationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _educationFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('EDUCATION', Icons.school),
            const SizedBox(height: 25),
            
            // List of education entries
            ...List.generate(_educations.length, (index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 25),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: BauhausColors.white,
                  border: Border.all(color: BauhausColors.black, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with education number and delete button
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: BauhausColors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: BauhausColors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'EDUCATION ${index + 1}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: BauhausColors.black,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        if (_educations.length > 1)
                          GestureDetector(
                            onTap: () => _removeEducation(index),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: BauhausColors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.delete,
                                color: BauhausColors.white,
                                size: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    _buildTextField(
                      controller: _educations[index].degreeController,
                      label: 'DEGREE',
                      hint: 'Bachelor of Science, Master of Arts, etc.',
                      validator: (value) {
                        if (index == 0 && (value == null || value.isEmpty)) {
                          return 'First degree is required';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 15),
                    
                    _buildTextField(
                      controller: _educations[index].schoolController,
                      label: 'SCHOOL/UNIVERSITY',
                      hint: 'University name',
                      validator: (value) {
                        if (index == 0 && (value == null || value.isEmpty)) {
                          return 'First school name is required';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 15),
                    
                    _buildTextField(
                      controller: _educations[index].graduationController,
                      label: 'GRADUATION YEAR',
                      hint: '2023',
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              );
            }),
            
            // Add more education button
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: BauhausColors.lightGray,
                border: Border.all(color: BauhausColors.black, width: 2),
              ),
              child: MaterialButton(
                onPressed: _addEducation,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add,
                      color: BauhausColors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ADD ANOTHER EDUCATION',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: BauhausColors.blue,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _skillsFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('SKILLS', Icons.star),
            const SizedBox(height: 25),
            
            _buildTextField(
              controller: _skillsController,
              label: 'TECHNICAL & SOFT SKILLS',
              hint: 'JavaScript, Python, Project Management, Communication, etc.\n(Separate with commas)',
              maxLines: 6,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please add at least one skill';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 20),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: BauhausColors.yellow.withOpacity(0.1),
                border: Border.all(color: BauhausColors.yellow, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb,
                        color: BauhausColors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'TIP',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: BauhausColors.black,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Include both technical skills (programming languages, software) and soft skills (leadership, communication, problem-solving).',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: BauhausColors.gray,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('RESUME PREVIEW', Icons.preview),
          const SizedBox(height: 25),
          
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: BauhausColors.white,
              border: Border.all(color: BauhausColors.black, width: 3),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  color: BauhausColors.blue,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nameController.text.toUpperCase(),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: BauhausColors.white,
                          letterSpacing: 2,
                        ),
                      ),
                      if (_emailController.text.isNotEmpty || _phoneController.text.isNotEmpty || _locationController.text.isNotEmpty)
                        const SizedBox(height: 10),
                      Text(
                        [_emailController.text, _phoneController.text, _locationController.text]
                            .where((text) => text.isNotEmpty)
                            .join(' • '),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: BauhausColors.yellow,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content sections
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary
                      if (_summaryController.text.isNotEmpty) ...[
                        _buildPreviewSection('SUMMARY', _summaryController.text),
                        const SizedBox(height: 20),
                      ],
                      
                      // Experience
                      if (_workExperiences.any((exp) => 
                          exp.jobTitleController.text.isNotEmpty || 
                          exp.companyController.text.isNotEmpty)) ...[
                        _buildPreviewSection('EXPERIENCE', ''),
                        const SizedBox(height: 10),
                        ...List.generate(_workExperiences.length, (index) {
                          final exp = _workExperiences[index];
                          if (exp.jobTitleController.text.isEmpty && 
                              exp.companyController.text.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            margin: const EdgeInsets.only(bottom: 15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (exp.jobTitleController.text.isNotEmpty)
                                  Text(
                                    exp.jobTitleController.text.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: BauhausColors.black,
                                    ),
                                  ),
                                if (exp.companyController.text.isNotEmpty || 
                                    exp.durationController.text.isNotEmpty)
                                  Text(
                                    '${exp.companyController.text}${exp.durationController.text.isNotEmpty ? ' • ${exp.durationController.text}' : ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: BauhausColors.gray,
                                    ),
                                  ),
                                if (exp.descriptionController.text.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    exp.descriptionController.text,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                      color: BauhausColors.black,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 10),
                      ],
                      
                      // Education
                      if (_educations.any((edu) => 
                          edu.degreeController.text.isNotEmpty || 
                          edu.schoolController.text.isNotEmpty)) ...[
                        _buildPreviewSection('EDUCATION', ''),
                        const SizedBox(height: 10),
                        ...List.generate(_educations.length, (index) {
                          final edu = _educations[index];
                          if (edu.degreeController.text.isEmpty && 
                              edu.schoolController.text.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            margin: const EdgeInsets.only(bottom: 15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (edu.degreeController.text.isNotEmpty)
                                  Text(
                                    edu.degreeController.text.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: BauhausColors.black,
                                    ),
                                  ),
                                if (edu.schoolController.text.isNotEmpty || 
                                    edu.graduationController.text.isNotEmpty)
                                  Text(
                                    '${edu.schoolController.text}${edu.graduationController.text.isNotEmpty ? ' • ${edu.graduationController.text}' : ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: BauhausColors.gray,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 10),
                      ],
                      
                      // Skills
                      if (_skillsController.text.isNotEmpty) ...[
                        _buildPreviewSection('SKILLS', _skillsController.text),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Export options
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: BauhausColors.yellow.withOpacity(0.1),
              border: Border.all(color: BauhausColors.yellow, width: 2),
            ),
            child: Column(
              children: [
                Text(
                  'EXPORT RESUME',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: BauhausColors.black,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: _buildExportButton('SAVE PDF', Icons.picture_as_pdf),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildExportButton('SHARE', Icons.share),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Local storage methods
  Future<void> _saveResumeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final resumeData = {
        'personalInfo': {
          'name': _nameController.text,
          'email': _emailController.text,
          'phone': _phoneController.text,
          'location': _locationController.text,
          'summary': _summaryController.text,
        },
        'workExperiences': _workExperiences.map((exp) => exp.toJson()).toList(),
        'educations': _educations.map((edu) => edu.toJson()).toList(),
        'skills': _skillsController.text,
        'lastSaved': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString('resume_data', jsonEncode(resumeData));
      
      // Show save confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Resume draft saved!',
            style: TextStyle(
              color: BauhausColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: BauhausColors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error saving draft: ${e.toString()}',
            style: TextStyle(
              color: BauhausColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: BauhausColors.red,
        ),
      );
    }
  }

  Future<void> _loadSavedResume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString('resume_data');
      
      if (savedData != null) {
        final resumeData = jsonDecode(savedData);
        
        // Load personal info
        _nameController.text = resumeData['personalInfo']['name'] ?? '';
        _emailController.text = resumeData['personalInfo']['email'] ?? '';
        _phoneController.text = resumeData['personalInfo']['phone'] ?? '';
        _locationController.text = resumeData['personalInfo']['location'] ?? '';
        _summaryController.text = resumeData['personalInfo']['summary'] ?? '';
        
        // Load work experiences
        final workExps = resumeData['workExperiences'] as List<dynamic>? ?? [];
        if (workExps.isNotEmpty) {
          // Dispose existing experiences
          for (var exp in _workExperiences) {
            exp.dispose();
          }
          _workExperiences.clear();
          
          // Load saved experiences
          for (var expData in workExps) {
            _workExperiences.add(WorkExperience.fromJson(expData));
          }
        }
        
        // Load educations
        final edus = resumeData['educations'] as List<dynamic>? ?? [];
        if (edus.isNotEmpty) {
          // Dispose existing educations
          for (var edu in _educations) {
            edu.dispose();
          }
          _educations.clear();
          
          // Load saved educations
          for (var eduData in edus) {
            _educations.add(Education.fromJson(eduData));
          }
        }
        
        // Load skills
        _skillsController.text = resumeData['skills'] ?? '';
        
        setState(() {});
      }
    } catch (e) {
      // Silently fail if there's an error loading data
      print('Error loading saved resume: $e');
    }
  }

  Future<void> _clearSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('resume_data');
    
    // Reset form
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _locationController.clear();
    _summaryController.clear();
    _skillsController.clear();
    
    // Reset experiences and educations
    for (var exp in _workExperiences) {
      exp.dispose();
    }
    for (var edu in _educations) {
      edu.dispose();
    }
    
    setState(() {
      _workExperiences = [WorkExperience()];
      _educations = [Education()];
      _currentStep = 0;
    });
    
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Resume data cleared!',
          style: TextStyle(
            color: BauhausColors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: BauhausColors.red,
      ),
    );
  }

  void _showLoadOptions() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString('resume_data');
    
    if (savedData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No saved resume found!',
            style: TextStyle(
              color: BauhausColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: BauhausColors.red,
        ),
      );
      return;
    }
    
    final resumeData = jsonDecode(savedData);
    final lastSaved = DateTime.parse(resumeData['lastSaved']);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          decoration: BoxDecoration(
            border: Border.all(color: BauhausColors.black, width: 4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: BauhausColors.yellow,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: BauhausColors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.folder_open,
                        color: BauhausColors.black,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        'LOAD RESUME',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: BauhausColors.black,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: BauhausColors.white,
                child: Column(
                  children: [
                    Text(
                      'Found saved resume draft:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: BauhausColors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: BauhausColors.lightGray,
                        border: Border.all(color: BauhausColors.gray, width: 1),
                      ),
                      child: Column(
                        children: [
                          Text(
                            resumeData['personalInfo']['name'] ?? 'Unnamed Resume',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: BauhausColors.black,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Last saved: ${_formatDateTime(lastSaved)}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: BauhausColors.gray,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),
                    
                    // Buttons
                    Row(
                      children: [
                        // Load button
                        Expanded(
                          child: Container(
                            height: 45,
                            color: BauhausColors.blue,
                            child: MaterialButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _loadSavedResume();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Resume loaded!',
                                      style: TextStyle(
                                        color: BauhausColors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    backgroundColor: BauhausColors.blue,
                                  ),
                                );
                              },
                              child: Text(
                                'LOAD',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: BauhausColors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 10),
                        
                        // Clear button
                        Expanded(
                          child: Container(
                            height: 45,
                            decoration: BoxDecoration(
                              color: BauhausColors.red,
                              border: Border.all(color: BauhausColors.black, width: 2),
                            ),
                            child: MaterialButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _showClearConfirmation();
                              },
                              child: Text(
                                'CLEAR',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: BauhausColors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 10),
                        
                        // Cancel button
                        Expanded(
                          child: Container(
                            height: 45,
                            decoration: BoxDecoration(
                              color: BauhausColors.lightGray,
                              border: Border.all(color: BauhausColors.gray, width: 2),
                            ),
                            child: MaterialButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                'CANCEL',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: BauhausColors.gray,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearConfirmation() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 300,
          decoration: BoxDecoration(
            border: Border.all(color: BauhausColors.black, width: 4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: BauhausColors.red,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: BauhausColors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.warning,
                        color: BauhausColors.red,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        'CLEAR DATA?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: BauhausColors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: BauhausColors.white,
                child: Column(
                  children: [
                    Text(
                      'Are you sure you want to clear all saved resume data?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: BauhausColors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'This action cannot be undone.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BauhausColors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    
                    // Buttons
                    Row(
                      children: [
                        // Cancel button
                        Expanded(
                          child: Container(
                            height: 45,
                            decoration: BoxDecoration(
                              color: BauhausColors.lightGray,
                              border: Border.all(color: BauhausColors.gray, width: 2),
                            ),
                            child: MaterialButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                'CANCEL',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: BauhausColors.gray,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 15),
                        
                        // Clear button
                        Expanded(
                          child: Container(
                            height: 45,
                            color: BauhausColors.red,
                            child: MaterialButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _clearSavedData();
                              },
                              child: Text(
                                'CLEAR ALL',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: BauhausColors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Helper methods for managing work experiences
  void _addWorkExperience() {
    setState(() {
      _workExperiences.add(WorkExperience());
    });
  }

  void _removeWorkExperience(int index) {
    if (_workExperiences.length > 1) {
      setState(() {
        _workExperiences[index].dispose();
        _workExperiences.removeAt(index);
      });
    }
  }

  // Helper methods for managing educations
  void _addEducation() {
    setState(() {
      _educations.add(Education());
    });
  }

  void _removeEducation(int index) {
    if (_educations.length > 1) {
      setState(() {
        _educations[index].dispose();
        _educations.removeAt(index);
      });
    }
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: BauhausColors.blue,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: BauhausColors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 15),
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: BauhausColors.black,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: BauhausColors.black,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: BauhausColors.black, width: 2),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            validator: validator,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: BauhausColors.black,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: BauhausColors.gray,
              ),
              filled: true,
              fillColor: BauhausColors.white,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 3,
              color: BauhausColors.blue,
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: BauhausColors.black,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        if (content.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: BauhausColors.black,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildExportButton(String text, IconData icon) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: BauhausColors.blue,
        border: Border.all(color: BauhausColors.black, width: 2),
      ),
      child: MaterialButton(
        onPressed: () async {
          if (text == 'SAVE PDF') {
            await _savePDF();
          } else if (text == 'SHARE') {
            await _shareResume();
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: BauhausColors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: BauhausColors.white,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Turns the form into the CV data the design engine uses, then opens
  /// the design picker with 4 free designs.
  void _openDesigns() {
    List<String> lines(String text) => text
        .split(RegExp(r'\n'))
        .map((l) => l.trim().replaceFirst(RegExp(r'^[-\u2022*]+\s*'), ''))
        .where((l) => l.isNotEmpty)
        .toList();

    final experience = _workExperiences
        .where((e) => e.jobTitleController.text.trim().isNotEmpty ||
                      e.companyController.text.trim().isNotEmpty)
        .map((e) {
          final desc = e.descriptionController.text.trim();
          final bullets = lines(desc);
          return <String, dynamic>{
            'title':       e.jobTitleController.text.trim(),
            'company':     e.companyController.text.trim(),
            'duration':    e.durationController.text.trim(),
            'description': desc,
            'bullets':     bullets.length > 1 ? bullets : <String>[],
          };
        })
        .toList();

    final education = _educations
        .where((e) => e.degreeController.text.trim().isNotEmpty ||
                      e.schoolController.text.trim().isNotEmpty)
        .map((e) => <String, dynamic>{
              'degree':      e.degreeController.text.trim(),
              'institution': e.schoolController.text.trim(),
              'year':        e.graduationController.text.trim(),
            })
        .toList();

    final skills = _skillsController.text
        .split(RegExp(r'[,\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Headline: most recent job title, else qualification.
    String headline = '';
    if (experience.isNotEmpty) headline = experience.first['title'] as String;
    if (headline.isEmpty && education.isNotEmpty) headline = education.first['degree'] as String;

    final data = <String, dynamic>{
      'name':           _nameController.text.trim(),
      'headline':       headline,
      'email':          _emailController.text.trim(),
      'phone':          _phoneController.text.trim(),
      'location':       _locationController.text.trim(),
      'linkedin':       '',
      'summary':        _summaryController.text.trim(),
      'experience':     experience,
      'education':      education,
      'skills':         skills,
      'certifications': <String>[],
      'achievements':   <String>[],
      'awards':         <String>[],
      'languages':      <String>[],
    };

    _saveResumeData(); // keep their progress
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ATSCVBuilderScreen(cameras: widget.cameras, buildData: data)));
  }

  Future<pw.Document> _generatePDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header section
              pw.Container(
                width: double.infinity,
                color: const PdfColor.fromInt(0xFF2E7D32),
                padding: const pw.EdgeInsets.all(20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      _nameController.text.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    if (_emailController.text.isNotEmpty || 
                        _phoneController.text.isNotEmpty || 
                        _locationController.text.isNotEmpty) ...[
                      pw.SizedBox(height: 10),
                      pw.Text(
                        [_emailController.text, _phoneController.text, _locationController.text]
                            .where((text) => text.isNotEmpty)
                            .join(' • '),
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFFFDD835), // Yellow
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              pw.SizedBox(height: 20),
              
              // Content sections
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 20),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Summary
                      if (_summaryController.text.isNotEmpty) ...[
                        _buildPDFSection('SUMMARY'),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          _summaryController.text,
                          style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.3),
                        ),
                        pw.SizedBox(height: 20),
                      ],
                      
                      // Experience
                      if (_workExperiences.any((exp) => 
                          exp.jobTitleController.text.isNotEmpty || 
                          exp.companyController.text.isNotEmpty)) ...[
                        _buildPDFSection('EXPERIENCE'),
                        pw.SizedBox(height: 15),
                        ...List.generate(_workExperiences.length, (index) {
                          final exp = _workExperiences[index];
                          if (exp.jobTitleController.text.isEmpty && 
                              exp.companyController.text.isEmpty) {
                            return pw.SizedBox.shrink();
                          }
                          return pw.Container(
                            margin: const pw.EdgeInsets.only(bottom: 15),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                if (exp.jobTitleController.text.isNotEmpty)
                                  pw.Text(
                                    exp.jobTitleController.text.toUpperCase(),
                                    style: pw.TextStyle(
                                      fontSize: 14,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                if (exp.companyController.text.isNotEmpty || 
                                    exp.durationController.text.isNotEmpty)
                                  pw.Text(
                                    '${exp.companyController.text}${exp.durationController.text.isNotEmpty ? ' • ${exp.durationController.text}' : ''}',
                                    style: pw.TextStyle(
                                      fontSize: 12,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.grey600,
                                    ),
                                  ),
                                if (exp.descriptionController.text.isNotEmpty) ...[
                                  pw.SizedBox(height: 5),
                                  pw.Text(
                                    exp.descriptionController.text,
                                    style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.3),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                        pw.SizedBox(height: 10),
                      ],
                      
                      // Education
                      if (_educations.any((edu) => 
                          edu.degreeController.text.isNotEmpty || 
                          edu.schoolController.text.isNotEmpty)) ...[
                        _buildPDFSection('EDUCATION'),
                        pw.SizedBox(height: 15),
                        ...List.generate(_educations.length, (index) {
                          final edu = _educations[index];
                          if (edu.degreeController.text.isEmpty && 
                              edu.schoolController.text.isEmpty) {
                            return pw.SizedBox.shrink();
                          }
                          return pw.Container(
                            margin: const pw.EdgeInsets.only(bottom: 15),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                if (edu.degreeController.text.isNotEmpty)
                                  pw.Text(
                                    edu.degreeController.text.toUpperCase(),
                                    style: pw.TextStyle(
                                      fontSize: 14,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                if (edu.schoolController.text.isNotEmpty || 
                                    edu.graduationController.text.isNotEmpty)
                                  pw.Text(
                                    '${edu.schoolController.text}${edu.graduationController.text.isNotEmpty ? ' • ${edu.graduationController.text}' : ''}',
                                    style: pw.TextStyle(
                                      fontSize: 12,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.grey600,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                        pw.SizedBox(height: 10),
                      ],
                      
                      // Skills
                      if (_skillsController.text.isNotEmpty) ...[
                        _buildPDFSection('SKILLS'),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          _skillsController.text,
                          style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.3),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildPDFSection(String title) {
    return pw.Row(
      children: [
        pw.Container(
          width: 30,
          height: 3,
          color: const PdfColor.fromInt(0xFF2E7D32),
        ),
        pw.SizedBox(width: 10),
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _showSaveSuccessDialog(String fileName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          decoration: BoxDecoration(
            border: Border.all(color: BauhausColors.black, width: 4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: BauhausColors.blue,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: BauhausColors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: BauhausColors.blue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        'PDF SAVED!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: BauhausColors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: BauhausColors.white,
                child: Column(
                  children: [
                    Icon(
                      Icons.picture_as_pdf,
                      color: BauhausColors.blue,
                      size: 48,
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Your resume has been saved successfully!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: BauhausColors.black,
                        letterSpacing: 1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: BauhausColors.lightGray,
                        border: Border.all(color: BauhausColors.gray, width: 1),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'FILE SAVED TO:',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: BauhausColors.gray,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            Platform.isAndroid ? 'Downloads Folder' : 'Documents Folder',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: BauhausColors.black,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            fileName,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: BauhausColors.gray,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),
                    
                    // OK button
                    Container(
                      width: double.infinity,
                      height: 50,
                      color: BauhausColors.blue,
                      child: MaterialButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'OK',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: BauhausColors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _savePDF() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: BauhausColors.white,
              border: Border.all(color: BauhausColors.black, width: 3),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: BauhausColors.blue,
                ),
                const SizedBox(height: 15),
                Text(
                  'GENERATING PDF...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: BauhausColors.black,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final pdf = await _generatePDF();
      final bytes = await pdf.save();

      // Get the downloads directory
      Directory? downloadsDirectory;
      if (Platform.isAndroid) {
        downloadsDirectory = Directory('/storage/emulated/0/Download');
      } else if (Platform.isIOS) {
        downloadsDirectory = await getApplicationDocumentsDirectory();
      }

      if (downloadsDirectory != null && await downloadsDirectory.exists()) {
        final fileName = '${_nameController.text.replaceAll(' ', '_')}_Resume_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final file = File('${downloadsDirectory.path}/$fileName');
        await file.writeAsBytes(bytes);

        // Close loading dialog
        Navigator.of(context).pop();

        // Show success popup dialog
        _showSaveSuccessDialog(fileName);
      } else {
        throw Exception('Downloads directory not found');
      }
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error saving PDF: ${e.toString()}',
            style: TextStyle(
              color: BauhausColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: BauhausColors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _shareResume() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: BauhausColors.white,
              border: Border.all(color: BauhausColors.black, width: 3),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: BauhausColors.blue,
                ),
                const SizedBox(height: 15),
                Text(
                  'PREPARING TO SHARE...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: BauhausColors.black,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final pdf = await _generatePDF();
      final bytes = await pdf.save();
      
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final fileName = '${_nameController.text.replaceAll(' ', '_')}_Resume.pdf';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      // Close loading dialog
      Navigator.of(context).pop();

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '${_nameController.text}\'s Resume',
        text: 'Here is my resume created with ITSAGO AI Interview Prep.',
      );
      
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error sharing resume: ${e.toString()}',
            style: TextStyle(
              color: BauhausColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: BauhausColors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildNavigationButtons() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: BauhausColors.white,
      child: Row(
        children: [
          // Previous button
          if (_currentStep > 0)
            Expanded(
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: BauhausColors.lightGray,
                  border: Border.all(color: BauhausColors.gray, width: 2),
                ),
                child: MaterialButton(
                  onPressed: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Text(
                    'PREVIOUS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: BauhausColors.gray,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          
          if (_currentStep > 0) const SizedBox(width: 15),
          
          // Next/Finish button
          Expanded(
            child: Container(
              height: 50,
              color: BauhausColors.blue,
              child: MaterialButton(
                onPressed: () {
                  if (_currentStep < 4) {
                    // Validate current step
                    bool isValid = true;
                    switch (_currentStep) {
                      case 0:
                        isValid = _personalFormKey.currentState?.validate() ?? false;
                        break;
                      case 1:
                        isValid = _experienceFormKey.currentState?.validate() ?? false;
                        break;
                      case 2:
                        isValid = _educationFormKey.currentState?.validate() ?? false;
                        break;
                      case 3:
                        isValid = _skillsFormKey.currentState?.validate() ?? false;
                        break;
                    }
                    
                    if (isValid) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  } else {
                    // Finish - generate 4 CV designs to choose from
                    _openDesigns();
                  }
                },
                child: Text(
                  _currentStep < 4 ? 'NEXT' : 'FINISH',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: BauhausColors.white,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 300,
          decoration: BoxDecoration(
            border: Border.all(color: BauhausColors.black, width: 4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: BauhausColors.blue,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: BauhausColors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        color: BauhausColors.blue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        'RESUME COMPLETE!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: BauhausColors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: BauhausColors.white,
                child: Column(
                  children: [
                    Text(
                      'Your resume has been successfully created!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: BauhausColors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    
                    // Done button
                    Container(
                      width: double.infinity,
                      height: 45,
                      color: BauhausColors.blue,
                      child: MaterialButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                          Navigator.of(context).pop(); // Go back to main menu
                        },
                        child: Text(
                          'DONE',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: BauhausColors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}