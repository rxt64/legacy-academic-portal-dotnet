using System.Collections.Generic;

namespace SIGEA.Web.Models
{
    /// <summary>Dashboard indicators. All values are computed in SQL Server.</summary>
    public class DashboardViewModel
    {
        public int StudentCount { get; set; }
        public int InstructorCount { get; set; }
        public int CourseCount { get; set; }
        public int DepartmentCount { get; set; }
        public int EnrollmentCount { get; set; }
        public int GradedCount { get; set; }
        public decimal? AverageGrade { get; set; }
        public decimal TotalBudget { get; set; }
        public List<DepartmentSummary> Departments { get; set; }
    }

    public class DepartmentSummary
    {
        public int DepartmentID { get; set; }
        public string Name { get; set; }
        public decimal Budget { get; set; }
        public int CourseCount { get; set; }
        public int EnrollmentCount { get; set; }
    }

    /// <summary>One line of an academic transcript.</summary>
    public class TranscriptLine
    {
        public int CourseID { get; set; }
        public string Title { get; set; }
        public int Credits { get; set; }
        public decimal? Grade { get; set; }
    }

    public class TranscriptViewModel
    {
        public int StudentID { get; set; }
        public string StudentName { get; set; }
        public List<TranscriptLine> Lines { get; set; }
        public decimal? Gpa { get; set; }
        public int TotalCredits { get; set; }
    }
}
