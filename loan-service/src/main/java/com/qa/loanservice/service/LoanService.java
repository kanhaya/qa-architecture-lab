package com.qa.loanservice.service;

import com.qa.loanservice.exception.LoanNotFoundException;
import com.qa.loanservice.model.Loan;
import com.qa.loanservice.model.LoanStatus;
import com.qa.loanservice.model.requests.CreateLoanRequest;
import com.qa.loanservice.model.requests.UpdateLoanStatusRequest;
import com.qa.loanservice.repository.LoanRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class LoanService {

    private static final Logger log = LoggerFactory.getLogger(LoanService.class);

    private final LoanRepository loanRepository;

    public LoanService(LoanRepository loanRepository) {
        this.loanRepository = loanRepository;
    }

    public List<Loan> getAllLoans() {
        long start = System.currentTimeMillis();
        List<Loan> loans = loanRepository.findAll();
        log.info("operation=getAllLoans count={} durationMs={}", loans.size(), System.currentTimeMillis() - start);
        return loans;
    }

    public Loan getLoanById(Long id) {
        long start = System.currentTimeMillis();
        Loan loan = loanRepository.findById(id)
                .orElseThrow(() -> new LoanNotFoundException(id));
        log.info("operation=getLoanById loanId={} status={} durationMs={}",
                id, loan.getStatus(), System.currentTimeMillis() - start);
        return loan;
    }

    public Loan createLoan(CreateLoanRequest request) {
        long start = System.currentTimeMillis();
        Loan loan = new Loan();
        loan.setCustomerName(request.getCustomerName());
        loan.setAmount(request.getAmount());
        loan.setStatus(LoanStatus.PENDING);

        Loan saved = loanRepository.save(loan);
        log.info("operation=createLoan loanId={} status={} durationMs={}",
                saved.getId(), saved.getStatus(), System.currentTimeMillis() - start);
        return saved;
    }

    public Loan updateStatus(Long id, UpdateLoanStatusRequest request) {
        long start = System.currentTimeMillis();
        Loan loan = loanRepository.findById(id)
                .orElseThrow(() -> new LoanNotFoundException(id));

        loan.setStatus(request.getStatus());
        Loan updated = loanRepository.save(loan);
        log.info("operation=updateStatus loanId={} status={} durationMs={}",
                id, updated.getStatus(), System.currentTimeMillis() - start);
        return updated;
    }

    public void deleteLoan(Long id) {
        long start = System.currentTimeMillis();
        if (!loanRepository.deleteById(id)) {
            throw new LoanNotFoundException(id);
        }
        log.info("operation=deleteLoan loanId={} durationMs={}", id, System.currentTimeMillis() - start);
    }
}
